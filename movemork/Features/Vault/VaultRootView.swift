//
//  VaultRootView.swift
//  movemork
//
//  MoveMark — Editorial header, staged entrance, VaultCoverCards (image-led, bottom-band anchor).
//

import SwiftUI

struct VaultRootView: View {
    @Binding var path: [AppRoute]
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showAddProperty = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .extraProperty
    @State private var previewByPropertyId: [UUID: (path: String, url: URL)] = [:]
    @State private var otherRentalSummaries: [UUID: (documented: Int, total: Int)] = [:]

    /// Only the featured (recent/first) card is expandable; others are static. Ensures chevron is always on the same card.
    private var featuredPropertyId: UUID? {
        let list = propertyStore.properties
        guard let first = list.first else { return nil }
        if let active = propertyStore.activePropertyId, list.contains(where: { $0.id == active }) {
            return active
        }
        return first.id
    }

    var body: some View {
        Group {
            if shouldShowLoading {
                loadingState
            } else if propertyStore.properties.isEmpty {
                emptyState
            } else {
                vaultsDashboard
            }
        }
        .sheet(isPresented: $showAddProperty) {
            NavigationStack {
                NewPropertyView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddProperty = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessionManager.userId) {
            await reload()
        }
    }

    private func loadPreviewURLs() async {
        var previews: [UUID: (path: String, url: URL)] = [:]
        for row in propertyStore.properties {
            if let preview = await propertyStore.previewImage(for: row.id) {
                previews[row.id] = preview
            }
        }
        previewByPropertyId = previews
    }

    /// Preload the featured property so its expansion tray has data; keeps chevron + expand behavior consistent.
    private func ensureFeaturedPropertyLoaded() async {
        guard let fid = featuredPropertyId, let userId = sessionManager.userId else { return }
        if propertyStore.currentProperty?.id != fid {
            await propertyStore.selectProperty(id: fid, userId: userId)
        }
    }

    private var otherProperties: [PropertyRow] {
        guard let fid = featuredPropertyId else { return [] }
        return propertyStore.properties.filter { $0.id != fid }
    }

    private var featuredPropertyRow: PropertyRow? {
        guard let fid = featuredPropertyId else { return nil }
        return propertyStore.properties.first(where: { $0.id == fid })
    }

    private let inspectionRepo = InspectionRepository()

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await inspectionRepo.signedURL(bucket: "inspection-media", path: path)
    }

    private var vaultsDashboard: some View {
        ProofHomeView(
            model: proofHomeModel,
            resolvePhotoURL: resolvePhotoURL,
            onAddRental: presentAddProperty,
            onOpenRental: { if let row = featuredPropertyRow { openVaultDetail(for: row) } },
            onPrimary: { openFeaturedVaultOrContinue() },
            onOpenRoom: { path.append(.roomDetail(roomID: $0)) },
            onAction: handleProofAction,
            onOpenOtherRental: { id in
                if let row = propertyStore.properties.first(where: { $0.id == id }) { openVaultDetail(for: row) }
            },
            onRetry: { Task { await reload() } }
        )
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadPreviewURLs() }
        .task(id: featuredPropertyId) { await ensureFeaturedPropertyLoaded() }
        .task(id: otherProperties.map(\.id)) { await loadOtherRentalSummaries() }
        .onChange(of: propertyStore.currentProperty?.id) { _, _ in
            trackFeaturedProofScoreIfNeeded()
        }
        .onAppear {
            trackFeaturedProofScoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadPreviewURLs() } }
        }
    }

    /// Everything Proof shows, from the same store queries the previous Proof used.
    private var proofHomeModel: ProofHomeModel {
        let row = featuredPropertyRow
        let prop = propertyStore.currentProperty.flatMap { $0.id == featuredPropertyId ? $0 : nil }
        let rooms = prop?.rooms ?? []

        // Newest saved photo per room, newest room first.
        let recent: [ProofHomeModel.Recent] = rooms.compactMap { room -> (Date, ProofHomeModel.Recent)? in
            guard let latest = room.evidence.filter({ !$0.photos.isEmpty }).max(by: { $0.createdAt < $1.createdAt }),
                  let photo = latest.photos.first else { return nil }
            let count = room.moveInPhotoTotal
            return (latest.createdAt, .init(id: room.id, roomName: room.name, photoCount: count,
                                            photoPath: photo.thumbnailPath ?? photo.filePath, capturedAt: latest.createdAt))
        }
        .sorted { $0.0 > $1.0 }
        .map(\.1)

        return ProofHomeModel(
            propertyName: row.map(displayName(for:)) ?? "Your rental",
            addressLine: row.map(locationText(for:)).flatMap { $0.isEmpty ? nil : $0 },
            documented: vaultDocumentedCount ?? 0,
            totalRooms: vaultTotalRooms ?? 0,
            nextRoomName: vaultNextRoomName,
            primaryTitle: featuredContinueProofTitle,
            photos: vaultPhotoCount ?? 0,
            records: vaultRecordCount ?? 0,
            issues: vaultIssueCount ?? 0,
            recent: Array(recent.prefix(8)),
            upcoming: upcomingRooms(rooms),
            actions: proofActions(for: prop),
            otherRentals: otherProperties.map { .init(id: $0.id, name: displayName(for: $0), status: otherRentalStatusLine(for: $0)) },
            errorMessage: propertyStore.errorMessage
        )
    }

    /// Rooms with no move-in proof yet, the next room first (same rule as the capture button).
    private func upcomingRooms(_ rooms: [RoomRecord]) -> [ProofHomeModel.Upcoming] {
        let empty = rooms.filter { room in !room.evidence.contains { !$0.photos.isEmpty || $0.photoCount > 0 } }
        let next = vaultNextRoomName
        return empty
            .sorted { a, b in (a.name == next ? 0 : 1) < (b.name == next ? 0 : 1) }
            .map { .init(id: $0.id, roomName: $0.name) }
    }

    /// Same sources and de-duplication as the previous Next actions + records sections.
    private func proofActions(for prop: PropertyRecord?) -> [ProofHomeModel.Action] {
        guard let prop else { return [] }
        var actions: [ProofHomeModel.Action] = []
        if let nudge = visibleNudge, !nudgeCoversMaintenance, !nudgeCoversDocuments {
            actions.append(.init(id: "nudge", kind: .nudge, title: nudge.title, subtitle: nudge.reason, icon: "sparkles"))
        }
        if propertyStore.missingSupportingRecordCount(for: prop) > 0 {
            for type in PropertyStore.moveInRequiredDocumentTypes where !DocumentRepository.documentTypeQueryKeys(type.rawValue)
                .contains(where: { prop.vaultDocuments.contains($0) }) {
                switch type {
                case .lease:
                    actions.append(.init(id: type.rawValue, kind: .document(type), title: "Lease", subtitle: "Add your lease agreement", icon: "doc.text", needed: true))
                case .depositReceipt:
                    actions.append(.init(id: type.rawValue, kind: .document(type), title: "Deposit receipt", subtitle: "Upload proof of deposit", icon: "receipt", needed: true))
                case .listingScreenshot:
                    actions.append(.init(id: type.rawValue, kind: .document(type), title: "Listing proof", subtitle: "Save original listing", icon: "photo", needed: true))
                default:
                    break
                }
            }
        }
        let issues = propertyStore.openIssueCount(for: prop)
        actions.append(.init(
            id: "maintenance", kind: .maintenance,
            title: "Maintenance issue",
            subtitle: issues > 0 ? (issues == 1 ? "1 open issue" : "\(issues) open issues") : "Report existing issues",
            icon: "wrench.adjustable"
        ))
        if propertyStore.isExportReady(for: prop) {
            actions.append(.init(id: "report", kind: .report, title: "Move-in report", subtitle: "Ready to share", icon: "doc.richtext"))
        }
        return actions
    }

    private func handleProofAction(_ action: ProofHomeModel.Action) {
        switch action.kind {
        case .document:
            if let row = featuredPropertyRow { openVaultDetail(for: row) }
        case .maintenance:
            path.append(.maintenance)
        case .report:
            path.append(.exports)
        case .nudge:
            if let nudge = visibleNudge, let prop = propertyStore.currentProperty {
                handleLifecycleNudge(nudge, property: prop)
            }
        }
    }

    private var visibleNudge: PropertyStore.LifecycleNudge? {
        guard let prop = propertyStore.currentProperty,
              let nudge = propertyStore.lifecycleNudge(for: prop) else { return nil }
        if case .finishRoomsBeforeUnpacking = nudge { return nil }
        return nudge
    }

    private var nudgeCoversMaintenance: Bool {
        if case .midLeaseMaintenance = visibleNudge { return true }
        return false
    }

    private var nudgeCoversDocuments: Bool {
        visibleNudge == .addLeaseAndDepositDocs
    }

    /// Genuinely incomplete or timely work only. Maintenance appears exactly once:
    /// "Review" when an issue is open, "Log" when none is.
    private func handleLifecycleNudge(_ nudge: PropertyStore.LifecycleNudge, property: PropertyRecord) {
        switch nudge {
        case .finishRoomsBeforeUnpacking:
            switch propertyStore.primaryNextAction(for: property) {
            case .captureRoom:
                path.append(.walkthrough)
            default:
                if let row = featuredPropertyRow { openVaultDetail(for: row) }
            }
        case .addLeaseAndDepositDocs, .midLeaseMaintenance:
            if let row = featuredPropertyRow { openVaultDetail(for: row) }
        case .makeMoveInReport:
            path.append(.exports)
        case .moveOutProofReminder:
            if subscriptionManager.hasPro {
                path.append(.moveOut)
            } else {
                activePaywallReason = .moveOutExport
                showPaywall = true
            }
        }
    }

    private func presentAddProperty() {
                if subscriptionManager.canCreateProperty(currentCount: propertyStore.properties.count) {
                    showAddProperty = true
                } else {
                    activePaywallReason = .extraProperty
                    showPaywall = true
                }
            }

    private func loadOtherRentalSummaries() async {
        guard let userId = sessionManager.userId else { return }
        var summaries: [UUID: (documented: Int, total: Int)] = [:]
        for row in otherProperties {
            let counts = await propertyStore.moveInProofCounts(for: row.id, userId: userId)
            summaries[row.id] = counts
        }
        otherRentalSummaries = summaries
    }

    private func otherRentalStatusLine(for row: PropertyRow) -> String {
        let documented: Int
        let total: Int

        if let prop = propertyStore.currentProperty, prop.id == row.id {
            documented = propertyStore.documentedRoomCount(for: prop)
            total = propertyStore.totalRoomCount(for: prop)
        } else if let summary = otherRentalSummaries[row.id] {
            documented = summary.documented
            total = summary.total
        } else {
            return "Loading proof status…"
        }

        if total == 0 {
            return "No rooms yet · Tap to set up"
        }
        if documented == 0 {
            return "0 of \(total) rooms ready · Start move-in proof"
        }
        return "\(documented) of \(total) rooms ready"
    }

    private var vaultDocumentedCount: Int? {
        guard let prop = propertyStore.currentProperty else { return nil }
        return propertyStore.documentedRoomCount(for: prop)
    }

    private var vaultTotalRooms: Int? {
        guard let prop = propertyStore.currentProperty else { return nil }
        return propertyStore.totalRoomCount(for: prop)
    }

    private var vaultPhotoCount: Int? {
        guard let prop = propertyStore.currentProperty else { return nil }
        return propertyStore.totalPhotoCount(for: prop)
    }

    private var vaultRecordCount: Int? {
        guard let prop = propertyStore.currentProperty else { return nil }
        return propertyStore.uploadedSupportingRecordCount(for: prop)
    }

    private var vaultIssueCount: Int? {
        guard let prop = propertyStore.currentProperty else { return nil }
        return propertyStore.openIssueCount(for: prop)
    }




    private var vaultNextRoomName: String? {
        guard let prop = propertyStore.currentProperty,
              case .captureRoom(_, let name) = propertyStore.primaryNextAction(for: prop) else { return nil }
        return name
    }


    private var featuredContinueProofTitle: String {
        guard let fid = featuredPropertyId,
              let prop = propertyStore.currentProperty, prop.id == fid else {
            return MMNextBestAction.continueProof.title
        }
        if propertyStore.documentedRoomCount(for: prop) == 0 {
            return "Start room proof"
        }
        return MMNextBestActionMapper.primaryTitle(for: propertyStore.primaryNextAction(for: prop))
    }

    private func openFeaturedVaultOrContinue() {
        guard let fid = featuredPropertyId,
              let row = propertyStore.properties.first(where: { $0.id == fid }) else { return }
        if let prop = propertyStore.currentProperty, prop.id == fid {
            switch propertyStore.primaryNextAction(for: prop) {
            case .captureRoom(let roomID, _):
                // The button names the room ("Capture Kitchen"), so open that room directly.
                path.append(.roomDetail(roomID: roomID))
            default:
                openVaultDetail(for: row)
            }
        } else {
            openVaultDetail(for: row)
        }
    }

    private func openVaultDetail(for row: PropertyRow) {
        guard let userId = sessionManager.userId else { return }
        Task {
            await propertyStore.selectProperty(id: row.id, userId: userId)
            await MainActor.run {
                path.append(.vaultDetail(propertyId: row.id))
            }
        }
    }

    private func trackFeaturedProofScoreIfNeeded() {
        guard let prop = propertyStore.currentProperty else { return }
        MoveMarkAnalytics.trackProofScoreIfNeeded(
            propertyStore.readinessScore(for: prop),
            propertyId: prop.id
        )
    }

    // MARK: - Empty / Loading

    private var emptyState: some View {
        ProofHomeEmptyView(
            errorMessage: propertyStore.errorMessage,
            onStart: presentAddProperty,
            onRetry: { Task { await reload() } }
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .tint(MoveMarkTheme.Light.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MoveMarkTheme.Light.surface.ignoresSafeArea())
            .accessibilityLabel(MMCopy.loadingProofTrail)
    }

    // MARK: - Helpers

    private func displayName(for row: PropertyRow) -> String {
        let t = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? row.addressLine1 : row.title
    }

    private func locationText(for row: PropertyRow) -> String {
        RentalLocation.line(city: row.city, province: row.provinceState)
    }

    private var shouldShowLoading: Bool {
        guard sessionManager.userId != nil else { return false }
        return !propertyStore.hasCompletedInitialFetch || propertyStore.isLoading
    }

    private func reload() async {
        guard let userId = sessionManager.userId else { return }
        await propertyStore.fetchAll(userId: userId)
    }
}
