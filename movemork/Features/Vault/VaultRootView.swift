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
    @State private var hasAnimatedIn = false
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
                    .navigationTitle("Add property")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showAddProperty = false
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
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

    private var vaultsDashboard: some View {
            ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardStack) {
                MMProofSectionHeader(
                    title: "Your proof",
                    subtitle: "Document now. Prove it later."
                ) {
                    MMProofHeaderAddButton(action: presentAddProperty)
                }
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 8)
                .animation(MMMotion.cardReveal.delay(0.04), value: hasAnimatedIn)

                    if let error = propertyStore.errorMessage {
                        MMErrorBanner(
                            message: error,
                            retryTitle: MMCopy.tryAgain,
                            onRetry: { Task { await reload() } }
                        )
                    }

                if let row = featuredPropertyRow {
                    primaryVaultCard(for: row)
                        .mmAppearRise(isVisible: hasAnimatedIn, delay: 0.06, offset: 6)
                }

                nextActionsSection
                    .padding(.top, MoveMarkTheme.Spacing.sectionGap - MoveMarkTheme.Spacing.cardStack)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .animation(MMMotion.cardReveal.delay(0.10), value: hasAnimatedIn)

                recordsSection
                    .padding(.top, MoveMarkTheme.Spacing.sectionGap - MoveMarkTheme.Spacing.cardStack)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .animation(MMMotion.cardReveal.delay(0.14), value: hasAnimatedIn)

                if !otherProperties.isEmpty {
                    MMSectionLabel("Other rentals")
                        .padding(.top, MoveMarkTheme.Spacing.sectionGap - MoveMarkTheme.Spacing.cardStack)

                    ForEach(otherProperties) { row in
                        MMProofListRow(
                            title: displayName(for: row),
                            subtitle: otherRentalStatusLine(for: row),
                            onTap: { openVaultDetail(for: row) }
                        )
                    }
                }

                MMSignedInScrollTailSpacer(kind: .rootTab)
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 10)
            .mmScrollContentTopInset(2)
            .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
            .scrollIndicators(.hidden, axes: .vertical)
        .mmProofShellBackground(heroFocus: true, ctaBloom: false)
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
            .onAppear {
                guard !hasAnimatedIn else { return }
            withAnimation(.easeOut(duration: 0.42)) { hasAnimatedIn = true }
        }
    }

    @ViewBuilder
    private func primaryVaultCard(for row: PropertyRow) -> some View {
        MMVaultProofHeroCard(
            propertyName: displayName(for: row),
            location: locationText(for: row).isEmpty ? nil : locationText(for: row),
            coverageLine: vaultCoverageLine,
            statsLine: vaultProofStatsLine,
            nextRoomName: vaultNextRoomName,
            progress: vaultCoverageProgress,
            previewPath: previewByPropertyId[row.id]?.path,
            previewURL: previewByPropertyId[row.id]?.url,
            primaryTitle: featuredContinueProofTitle,
            onPrimary: { openFeaturedVaultOrContinue() },
            reportReadyLine: featuredReportReady ? "Move-in report ready" : nil,
            onViewReport: { path.append(.exports) },
            documentedCount: vaultDocumentedCount,
            totalRooms: vaultTotalRooms,
            photoCount: vaultPhotoCount,
            recordCount: vaultRecordCount,
            issueCount: vaultIssueCount,
            lastProofLine: vaultLastProofLine
        )
    }

    private var featuredReportReady: Bool {
        guard let prop = propertyStore.currentProperty else { return false }
        return propertyStore.isExportReady(for: prop) && propertyStore.documentedRoomCount(for: prop) > 0
    }

    /// Hero already carries "capture the next room", so that nudge is not repeated here.
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
    @ViewBuilder
    private var nextActionsSection: some View {
        if let prop = propertyStore.currentProperty {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardGap) {
                MMSectionLabel("Next actions")

                if let nudge = visibleNudge {
                    MMLifecycleNudgeCard(nudge: nudge) {
                        handleLifecycleNudge(nudge, property: prop)
                    }
                }

                if !nudgeCoversDocuments {
                    missingDocsCard
                }

                if !nudgeCoversMaintenance {
                    let issues = propertyStore.openIssueCount(for: prop)
                    ProofTaskCard(
                        title: issues > 0 ? "Review maintenance issue" : "Log maintenance issue",
                        reason: issues > 0
                            ? (issues == 1 ? "1 open issue" : "\(issues) open issues")
                            : "Timestamp repairs and problems.",
                        action: { path.append(.maintenance) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        if let prop = propertyStore.currentProperty {
            let receipts = propertyStore.leaseAndDepositReceiptCount(for: prop)
            let reportReady = propertyStore.isExportReady(for: prop)
            let hasRoomProof = propertyStore.documentedRoomCount(for: prop) > 0

            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardGap) {
                MMSectionLabel("Your records")

                ProofTaskCard(
                    title: "Lease & deposit records",
                    reason: "\(min(receipts, 2)) of 2 added",
                    action: {
                        if let row = featuredPropertyRow { openVaultDetail(for: row) }
                    }
                )

                if reportReady || hasRoomProof {
                    ProofTaskCard(
                        title: "Move-in report",
                        reason: reportReady
                            ? "Shareable PDF from your saved proof"
                            : "Builds from your documented rooms",
                        action: { path.append(.exports) },
                        statusLabel: reportReady ? "Ready" : nil,
                        statusTone: .success
                    )
                }
            }
        }
    }

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

    @ViewBuilder
    private var missingDocsCard: some View {
        if let prop = propertyStore.currentProperty,
           propertyStore.missingSupportingRecordCount(for: prop) > 0,
           let missing = PropertyStore.moveInRequiredDocumentTypes.first(where: { type in
               !DocumentRepository.documentTypeQueryKeys(type.rawValue)
                   .contains { prop.vaultDocuments.contains($0) }
           }) {
            ProofTaskCard(
                title: missing.displayTitle,
                reason: "Add proof of your \(missing.displayTitle.lowercased()).",
                action: {
                    if let row = propertyStore.properties.first(where: { $0.id == prop.id }) {
                        openVaultDetail(for: row)
                    }
                },
                statusLabel: "Needed",
                statusTone: .warning
            )
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

    private var vaultLastProofLine: String? {
        guard let prop = propertyStore.currentProperty else { return nil }
        guard let latest = prop.rooms.flatMap(\.evidence).map(\.createdAt).max() else { return nil }
        let day = latest.formatted(.dateTime.month(.abbreviated).day())
        let time = latest.formatted(.dateTime.hour().minute())
        return "\(day) · \(time)"
    }

    private var vaultCoverageLine: String {
        guard let prop = propertyStore.currentProperty else {
            let count = propertyStore.properties.count
            return count == 1 ? "1 vault" : "\(count) vaults"
        }
        let documented = propertyStore.documentedRoomCount(for: prop)
        let total = propertyStore.totalRoomCount(for: prop)
        if total == 0 { return "Add rooms to start documenting" }
        return "\(documented) of \(total) rooms documented"
    }

    private var vaultProofStatsLine: String? {
        guard let prop = propertyStore.currentProperty else { return nil }
        let photos = propertyStore.totalPhotoCount(for: prop)
        let receipts = min(propertyStore.leaseAndDepositReceiptCount(for: prop), 2)
        let photoText = photos == 1 ? "1 photo" : "\(photos) photos"
        return "\(photoText) · \(receipts) of 2 records"
    }

    private var vaultNextRoomName: String? {
        guard let prop = propertyStore.currentProperty,
              case .captureRoom(_, let name) = propertyStore.primaryNextAction(for: prop) else { return nil }
        return name
    }

    /// Rooms documented ÷ rooms — the same fact the coverage line states.
    private var vaultCoverageProgress: Double {
        guard let prop = propertyStore.currentProperty else { return 0 }
        let total = propertyStore.totalRoomCount(for: prop)
        guard total > 0 else { return 0 }
        return Double(propertyStore.documentedRoomCount(for: prop)) / Double(total)
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
        ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardStack) {
                MMProofSectionHeader(
                    title: "Your proof",
                    subtitle: "Document now. Prove it later."
                ) {
                    MMProofHeaderAddButton(action: presentAddProperty)
                }

                if let error = propertyStore.errorMessage {
                    MMErrorBanner(
                        message: error,
                        retryTitle: MMCopy.tryAgain,
                        onRetry: { Task { await reload() } }
                    )
                } else {
                    MMEmptyState(
                        systemImage: "building.columns.fill",
                        title: "Your first vault",
                        message: "Add your rental, then document each room before you settle in.",
                        primaryTitle: "Start move-in proof",
                        primaryAction: {
                            if subscriptionManager.canCreateProperty(currentCount: propertyStore.properties.count) {
                                showAddProperty = true
                            } else {
                                activePaywallReason = .extraProperty
                                showPaywall = true
                            }
                        }
                    )
                }

                MMSignedInScrollTailSpacer(kind: .rootTab)
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 18)
            .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
        }
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
    }

    private var loadingState: some View {
        MMLoadingState(message: MMCopy.loadingProofTrail)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mmProofShellBackground(heroFocus: false, ctaBloom: false)
    }

    // MARK: - Helpers

    private func displayName(for row: PropertyRow) -> String {
        let t = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? row.addressLine1 : row.title
    }

    private func locationText(for row: PropertyRow) -> String {
        [row.city, row.provinceState]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
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
