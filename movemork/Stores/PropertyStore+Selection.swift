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

    /// First evidence image URL for a property (inspection or maintenance). Use for vault card hero.
    func previewImageURL(for propertyId: UUID) async -> URL? {
        let files = try? await inspectionRepo.fetchEvidenceFiles(propertyId: propertyId)
        guard let first = files?.first else { return nil }
        let bucket = first.maintenanceIssueId != nil ? "maintenance-media" : "inspection-media"
        return try? await inspectionRepo.signedURL(bucket: bucket, path: first.filePath)
    }

    /// Call on sign-out to prevent stale data from showing for a different user.
    func clear() {
        Task { await MoveMarkSignedURLCache.shared.removeAll() }
        let was = currentProperty?.id.uuidString ?? "nil"
        currentProperty = nil
        properties = []
        activePropertyId = nil
        maintenanceLog = []
        disputeDraft = DisputeDraft()
        errorMessage = nil
        hasCompletedInitialFetch = false
        #if DEBUG
        print("👋 PropertyStore.clear(); currentProperty was \(was)")
        #endif
    }

    func fetchAll(userId: UUID) async {
        errorMessage = nil
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

            let savedId = UserDefaults.standard.string(forKey: Self.persistedActivePropertyIdKey(userId: userId))
                .flatMap { UUID(uuidString: $0) }
            let targetId = savedId.flatMap { id in fetched.first(where: { $0.id == id })?.id } ?? fetched[0].id
            activePropertyId = targetId
            UserDefaults.standard.set(targetId.uuidString, forKey: Self.persistedActivePropertyIdKey(userId: userId))

            guard let row = fetched.first(where: { $0.id == targetId }) else {
                currentProperty = nil
                maintenanceLog = []
                return
            }

            let (record, issues) = try await hydrateProperty(row, userId: userId)
            currentProperty = record
            maintenanceLog = issues
            errorMessage = nil
        } catch {
            errorMessage = MoveMarkFlowMessage.propertyListLoadFailed(error)
            currentProperty = nil
            maintenanceLog = []
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
        guard let row = properties.first(where: { $0.id == id }) else { return }
        do {
            let (record, issues) = try await hydrateProperty(row, userId: userId)
            currentProperty = record
            maintenanceLog = issues
            errorMessage = nil
        } catch {
            errorMessage = MoveMarkFlowMessage.propertySwitchLoadFailed(error)
            maintenanceLog = []
        }
    }
}
