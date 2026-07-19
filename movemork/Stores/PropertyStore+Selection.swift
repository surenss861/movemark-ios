//
//  PropertyStore+Selection.swift
//  movemork
//
//  Which property is active; load / switch / clear; preview image for list.
//

import Foundation

extension PropertyStore {

    static func persistedActivePropertyIdKey(userId: UUID) -> String {
        "MoveMark.activePropertyId.\(userId.uuidString)"
    }

    /// Resolve a hydrated property by id. For single-active-property flow, only the active property is hydrated; returns nil if id != currentProperty?.id.
    func propertyRecord(for id: UUID) -> PropertyRecord? {
        guard currentProperty?.id == id else { return nil }
        return currentProperty
    }

    /// Move-in room counts for list rows without switching the active property.
    func moveInProofCounts(for propertyId: UUID, userId: UUID) async -> (documented: Int, total: Int) {
        if let record = currentProperty, record.id == propertyId {
            return (
                documentedRoomCount(for: record),
                totalRoomCount(for: record)
            )
        }
        guard let row = properties.first(where: { $0.id == propertyId }) else {
            return (0, 0)
        }
        guard let (record, _) = try? await hydrateProperty(row, userId: userId) else {
            return (0, 0)
        }
        return (documentedRoomCount(for: record), totalRoomCount(for: record))
    }

    /// Most recent evidence image URL for a property (inspection or maintenance). Use for vault card hero.
    func previewImageURL(for propertyId: UUID) async -> URL? {
        await previewImage(for: propertyId)?.url
    }

    /// Same as ``previewImageURL(for:)`` but also returns the stable storage path, so callers can key
    /// ``MMCachedAsyncImage`` by path instead of by the (re-mintable) signed URL.
    func previewImage(for propertyId: UUID) async -> (path: String, url: URL)? {
        guard let first = try? await inspectionRepo.fetchFirstEvidenceFile(propertyId: propertyId) else { return nil }
        let bucket = first.maintenanceIssueId != nil ? "maintenance-media" : "inspection-media"
        let thumbPath = first.thumbnailPath ?? first.filePath
        guard let url = try? await inspectionRepo.signedURL(bucket: bucket, path: thumbPath) else { return nil }
        return (thumbPath, url)
    }

    /// Call on sign-out to prevent stale data from showing for a different user.
    func clear() {
        Task { await MoveMarkSignedURLCache.shared.removeAll() }
        PropertySnapshotCache.shared.removeAll()
        let was = currentProperty?.id.uuidString ?? "nil"
        currentProperty = nil
        properties = []
        activePropertyId = nil
        maintenanceLog = []
        errorMessage = nil
        hasCompletedInitialFetch = false
        #if DEBUG
        print("👋 PropertyStore.clear(); currentProperty was \(was)")
        #endif
    }

    func fetchAll(userId: UUID) async {
        errorMessage = nil

        // Instant local read: if we have a cached snapshot for the last-active property, publish it
        // immediately (synchronous, no network wait) so the UI isn't blank while the fetch below runs —
        // or stays blank if it fails offline.
        let savedId = UserDefaults.standard.string(forKey: Self.persistedActivePropertyIdKey(userId: userId))
            .flatMap { UUID(uuidString: $0) }
        if let savedId, let cached = PropertySnapshotCache.shared.load(propertyId: savedId) {
            currentProperty = cached.record
            maintenanceLog = cached.maintenance
        }

        isLoading = true
        defer {
            isLoading = false
            hasCompletedInitialFetch = true
        }

        do {
            let fetched = try await propertyRepo.fetchProperties(userId: userId)
            properties = fetched
            guard !fetched.isEmpty else {
                currentProperty = nil
                activePropertyId = nil
                maintenanceLog = []
                return
            }

            let targetId = savedId.flatMap { id in fetched.first(where: { $0.id == id })?.id } ?? fetched[0].id
            activePropertyId = targetId
            UserDefaults.standard.set(targetId.uuidString, forKey: Self.persistedActivePropertyIdKey(userId: userId))

            guard let row = fetched.first(where: { $0.id == targetId }) else {
                currentProperty = nil
                maintenanceLog = []
                return
            }

            // The seeded cache above may not match `targetId` (e.g. no saved id yet, or it pointed at a
            // property that's since been removed) — re-seed from the actual target's cache in that case.
            if currentProperty?.id != targetId, let cached = PropertySnapshotCache.shared.load(propertyId: targetId) {
                currentProperty = cached.record
                maintenanceLog = cached.maintenance
            }

            let (record, issues) = try await hydrateProperty(row, userId: userId)
            currentProperty = record
            maintenanceLog = issues
            errorMessage = nil
            PropertySnapshotCache.shared.save(propertyId: targetId, record: record, maintenance: issues)
        } catch {
            errorMessage = MoveMarkFlowMessage.propertyListLoadFailed(error)
            // Don't blank out data already on screen (from the cache seed above, or a prior successful
            // load) just because this refresh failed — only clear if there's genuinely nothing to show.
            if currentProperty == nil {
                maintenanceLog = []
            }
        }
    }

    /// Re-hydrates the active property after a successful save. Does **not** clear `currentProperty` on failure (avoids false “save failed” when refresh/preview steps flake).
    /// - Returns: `true` if hydration succeeded; `false` if the reload failed (local optimistic state is preserved).
    @discardableResult
    func refreshActivePropertyHydration(userId: UUID) async -> Bool {
        guard let activeId = activePropertyId,
              let row = properties.first(where: { $0.id == activeId }) else {
            await fetchAll(userId: userId)
            return errorMessage == nil
        }
        do {
            let (record, issues) = try await hydrateProperty(row, userId: userId)
            currentProperty = record
            maintenanceLog = issues
            errorMessage = nil
            PropertySnapshotCache.shared.save(propertyId: activeId, record: record, maintenance: issues)
            return true
        } catch {
            #if DEBUG
            print("MoveMark: refreshActivePropertyHydration failed (keeping local state):", error.localizedDescription)
            #endif
            return false
        }
    }

    /// Switches the active property and hydrates it. Call after fetchAll has run so `properties` is populated.
    func selectProperty(id: UUID, userId: UUID) async {
        guard properties.contains(where: { $0.id == id }) else { return }
        errorMessage = nil
        activePropertyId = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.persistedActivePropertyIdKey(userId: userId))

        // Instant local read: show the cached snapshot for the newly-selected property (if any) before
        // the RPC hydration below completes, so switching properties isn't a blank screen while it loads.
        if let cached = PropertySnapshotCache.shared.load(propertyId: id) {
            currentProperty = cached.record
            maintenanceLog = cached.maintenance
        }

        guard let row = properties.first(where: { $0.id == id }) else { return }
        do {
            let (record, issues) = try await hydrateProperty(row, userId: userId)
            currentProperty = record
            maintenanceLog = issues
            errorMessage = nil
            PropertySnapshotCache.shared.save(propertyId: id, record: record, maintenance: issues)
        } catch {
            errorMessage = MoveMarkFlowMessage.propertySwitchLoadFailed(error)
            // Keep whatever's already on screen (the cache seed above, if any) rather than clearing it —
            // a failed refresh shouldn't blank out data the user can already see.
        }
    }
}
