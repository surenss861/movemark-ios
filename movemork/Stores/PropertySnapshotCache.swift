//
//  PropertySnapshotCache.swift
//  movemork
//
//  Offline snapshot: persists the last successfully-hydrated (PropertyRecord, [MaintenanceRecord]) pair per
//  property so launch/switch can publish from disk while the RPC refresh happens in the background.
//  This is intentionally minimal — "local read first, then refresh" — not an offline-write/sync system.
//

import Foundation
import OSLog
import SwiftData

/// SwiftData row: one cached hydration snapshot per property, keyed by property id.
/// Stores `PropertyRecord`/`[MaintenanceRecord]` re-encoded as JSON rather than as native SwiftData
/// relationships — both are already `Codable`, so this reuses that instead of modeling every nested type
/// (`RoomRecord`, `EvidenceRecord`, ...) as its own `@Model`.
@Model
final class CachedPropertySnapshot {
    @Attribute(.unique) var propertyId: UUID
    var recordData: Data
    var maintenanceData: Data
    var cachedAt: Date

    init(propertyId: UUID, recordData: Data, maintenanceData: Data, cachedAt: Date) {
        self.propertyId = propertyId
        self.recordData = recordData
        self.maintenanceData = maintenanceData
        self.cachedAt = cachedAt
    }
}

// MARK: - SwiftData isolation

/// Owns the `ModelContext`. `@ModelActor` serialises access on its own executor, which is what keeps
/// SQLite work off the main actor — the store deals only in `Data`, so no `@Model` object ever escapes.
@ModelActor
actor PropertySnapshotModelStore {
    func loadData(propertyId: UUID) throws -> (recordData: Data, maintenanceData: Data)? {
        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        guard let row = try modelContext.fetch(descriptor).first else { return nil }
        return (row.recordData, row.maintenanceData)
    }

    func saveData(propertyId: UUID, recordData: Data, maintenanceData: Data) throws {
        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.recordData = recordData
            existing.maintenanceData = maintenanceData
            existing.cachedAt = Date()
        } else {
            modelContext.insert(
                CachedPropertySnapshot(
                    propertyId: propertyId,
                    recordData: recordData,
                    maintenanceData: maintenanceData,
                    cachedAt: Date()
                )
            )
        }
        try modelContext.save()
    }

    func removeRow(propertyId: UUID) throws {
        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func removeAllRows() throws {
        try modelContext.delete(model: CachedPropertySnapshot.self)
        try modelContext.save()
    }
}

// MARK: - Cache

/// Local read/write of the per-property snapshot cache.
///
/// Deliberately an `actor`, not `@MainActor`: container creation, the SwiftData fetch, and the nested
/// JSON coding all used to run on the main actor at launch, which is exactly the shape that stalls the
/// UI thread. Callers `await` a finished value type and publish it themselves.
///
/// The guarantee this offers is "read local before starting the remote refresh, without blocking the
/// main actor" — not the old "publish before any suspension". Callers see cached data a frame or two
/// later than they used to; that is the trade for not freezing.
///
/// The cache is optional throughout: every failure degrades to a miss, never to an error the caller
/// must handle.
actor PropertySnapshotCache {
    static let shared = PropertySnapshotCache()

    private var store: PropertySnapshotModelStore?
    /// Container creation is attempted once. A failure disables the cache for the process rather than
    /// retrying the same expensive failure on every read.
    private var containerUnavailable = false

    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "MoveMark",
        category: "PropertySnapshotCache"
    )
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MoveMark",
        category: "PropertySnapshotCache"
    )

    private func modelStore() -> PropertySnapshotModelStore? {
        if let store { return store }
        guard !containerUnavailable else { return nil }

        let state = Self.signposter.beginInterval("snapshot.container_init")
        let clock = ContinuousClock()
        let start = clock.now
        defer {
            Self.signposter.endInterval("snapshot.container_init", state)
            Self.log.debug("snapshot.container_init \(Self.ms(start, clock), privacy: .public)ms")
        }

        do {
            let container = try ModelContainer(for: CachedPropertySnapshot.self)
            let created = PropertySnapshotModelStore(modelContainer: container)
            store = created
            return created
        } catch {
            containerUnavailable = true
            Self.log.error("snapshot container init failed; offline snapshot disabled this launch")
            return nil
        }
    }

    /// Loads the cached snapshot for `propertyId`, if any. Local only — no network.
    func load(propertyId: UUID) async -> (record: PropertyRecord, maintenance: [MaintenanceRecord])? {
        guard let store = modelStore() else { return nil }
        let clock = ContinuousClock()

        do {
            let fetchState = Self.signposter.beginInterval("snapshot.fetch")
            let fetchStart = clock.now
            let data = try await store.loadData(propertyId: propertyId)
            Self.signposter.endInterval("snapshot.fetch", fetchState)
            Self.log.debug("snapshot.fetch \(Self.ms(fetchStart, clock), privacy: .public)ms hit=\(data != nil, privacy: .public)")

            guard let data else { return nil }

            let decodeState = Self.signposter.beginInterval("snapshot.decode")
            let decodeStart = clock.now
            defer { Self.signposter.endInterval("snapshot.decode", decodeState) }

            let decoder = JSONDecoder()
            let record = try decoder.decode(PropertyRecord.self, from: data.recordData)
            let maintenance = (try? decoder.decode([MaintenanceRecord].self, from: data.maintenanceData)) ?? []

            Self.log.debug(
                """
                snapshot.decode \(Self.ms(decodeStart, clock), privacy: .public)ms \
                record_bytes=\(data.recordData.count, privacy: .public) \
                rooms=\(record.rooms.count, privacy: .public) \
                maintenance=\(maintenance.count, privacy: .public)
                """
            )
            return (record, maintenance)
        } catch {
            Self.log.error("snapshot load failed; treating as a miss")
            return nil
        }
    }

    /// Replaces (or creates) the cached snapshot for `propertyId` after a successful hydration.
    func save(propertyId: UUID, record: PropertyRecord, maintenance: [MaintenanceRecord]) async {
        guard let store = modelStore() else { return }
        let clock = ContinuousClock()

        do {
            let encodeState = Self.signposter.beginInterval("snapshot.encode")
            let encodeStart = clock.now
            let encoder = JSONEncoder()
            let recordData = try encoder.encode(record)
            let maintenanceData = (try? encoder.encode(maintenance)) ?? Data()
            Self.signposter.endInterval("snapshot.encode", encodeState)
            Self.log.debug("snapshot.encode \(Self.ms(encodeStart, clock), privacy: .public)ms bytes=\(recordData.count, privacy: .public)")

            let saveState = Self.signposter.beginInterval("snapshot.save")
            let saveStart = clock.now
            try await store.saveData(
                propertyId: propertyId,
                recordData: recordData,
                maintenanceData: maintenanceData
            )
            Self.signposter.endInterval("snapshot.save", saveState)
            Self.log.debug("snapshot.save \(Self.ms(saveStart, clock), privacy: .public)ms")
        } catch {
            Self.log.error("snapshot save failed; cache left unchanged")
        }
    }

    /// Removes the cached snapshot for one property (e.g. property deleted).
    func remove(propertyId: UUID) async {
        guard let store = modelStore() else { return }
        do { try await store.removeRow(propertyId: propertyId) } catch {
            Self.log.error("snapshot remove failed")
        }
    }

    /// Clears every cached snapshot. Sign-out awaits this before a new user can hydrate, so one
    /// account's snapshots can never survive into the next session.
    func removeAll() async {
        guard let store = modelStore() else { return }
        do { try await store.removeAllRows() } catch {
            Self.log.error("snapshot removeAll failed")
        }
    }

    /// Elapsed milliseconds, for logging only. No identifiers or evidence content is ever logged.
    private static func ms(_ start: ContinuousClock.Instant, _ clock: ContinuousClock) -> Int {
        Int(start.duration(to: clock.now) / .milliseconds(1))
    }
}
