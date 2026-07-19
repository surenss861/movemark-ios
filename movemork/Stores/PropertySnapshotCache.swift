//
//  PropertySnapshotCache.swift
//  movemork
//
//  Offline snapshot: persists the last successfully-hydrated (PropertyRecord, [MaintenanceRecord]) pair per
//  property so launch/switch can publish instantly from disk while the RPC refresh happens in the background.
//  This is intentionally minimal — "instant local read, then refresh" — not an offline-write/sync system.
//

import Foundation
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

/// Synchronous (no network, no async hop) local read/write of the per-property snapshot cache.
/// `@MainActor`-bound like `PropertyStore` so a cache hit can publish into `currentProperty` immediately,
/// before the RPC refresh has even started.
@MainActor
final class PropertySnapshotCache {
    static let shared = PropertySnapshotCache()

    private let container: ModelContainer?

    private init() {
        do {
            container = try ModelContainer(for: CachedPropertySnapshot.self)
        } catch {
            #if DEBUG
            print("MoveMark: PropertySnapshotCache ModelContainer init failed (offline snapshot disabled this launch):", error)
            #endif
            container = nil
        }
    }

    private var context: ModelContext? {
        container?.mainContext
    }

    /// Loads the cached snapshot for `propertyId`, if any. Pure local disk read — safe to call before any network request.
    func load(propertyId: UUID) -> (record: PropertyRecord, maintenance: [MaintenanceRecord])? {
        guard let context else { return nil }
        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        guard let row = (try? context.fetch(descriptor))?.first else { return nil }

        let decoder = JSONDecoder()
        guard let record = try? decoder.decode(PropertyRecord.self, from: row.recordData) else { return nil }
        let maintenance = (try? decoder.decode([MaintenanceRecord].self, from: row.maintenanceData)) ?? []
        return (record, maintenance)
    }

    /// Replaces (or creates) the cached snapshot for `propertyId` after a successful hydration.
    func save(propertyId: UUID, record: PropertyRecord, maintenance: [MaintenanceRecord]) {
        guard let context else { return }
        let encoder = JSONEncoder()
        guard let recordData = try? encoder.encode(record) else { return }
        let maintenanceData = (try? encoder.encode(maintenance)) ?? Data()

        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.recordData = recordData
            existing.maintenanceData = maintenanceData
            existing.cachedAt = Date()
        } else {
            context.insert(CachedPropertySnapshot(
                propertyId: propertyId,
                recordData: recordData,
                maintenanceData: maintenanceData,
                cachedAt: Date()
            ))
        }
        try? context.save()
    }

    /// Removes the cached snapshot for one property (e.g. property deleted).
    func remove(propertyId: UUID) {
        guard let context else { return }
        let target = propertyId
        let descriptor = FetchDescriptor<CachedPropertySnapshot>(
            predicate: #Predicate { $0.propertyId == target }
        )
        guard let existing = (try? context.fetch(descriptor))?.first else { return }
        context.delete(existing)
        try? context.save()
    }

    /// Clears every cached snapshot (e.g. on sign-out, matching ``PropertyStore/clear()``).
    func removeAll() {
        guard let context else { return }
        try? context.delete(model: CachedPropertySnapshot.self)
        try? context.save()
    }
}
