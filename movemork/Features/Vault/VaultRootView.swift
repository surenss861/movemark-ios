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
    @State private var previewURLByPropertyId: [UUID: URL] = [:]
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
        var urls: [UUID: URL] = [:]
        for row in propertyStore.properties {
            if let url = await propertyStore.previewImageURL(for: row.id) {
                urls[row.id] = url
            }
        }
        previewURLByPropertyId = urls
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
                    subtitle: "What rental needs proof next?"
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

                missingDocsCard
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .animation(MMMotion.cardReveal.delay(0.12), value: hasAnimatedIn)

                vaultSecondaryTasks
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .animation(MMMotion.cardReveal.delay(0.14), value: hasAnimatedIn)

                if !otherProperties.isEmpty {
                    Text("Other rentals")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .padding(.top, 4)

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
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
        .task { await loadPreviewURLs() }
        .task(id: featuredPropertyId) { await ensureFeaturedPropertyLoaded() }
        .task(id: otherProperties.map(\.id)) { await loadOtherRentalSummaries() }
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
        let prop = propertyStore.currentProperty
        let featuredRoom = prop?.rooms.first(where: { room in
            !room.evidence.contains(where: { $0.photoCount > 0 })
        }) ?? prop?.rooms.first(where: { room in
            room.evidence.contains(where: { $0.photoCount > 0 })
        })
        let featuredPhotoCount = featuredRoom?.evidence.reduce(0) { $0 + $1.photoCount } ?? 0
        MMVaultProofHeroCard(
            propertyName: displayName(for: row),
            location: locationText(for: row).isEmpty ? nil : locationText(for: row),
            progressLine: vaultProofProgressHeadline,
            nextLine: vaultHeroNextLine,
            progress: vaultProofProgressValue,
            previewURL: previewURLByPropertyId[row.id],
            roomName: featuredRoom?.name,
            photoCount: featuredPhotoCount,
            primaryTitle: featuredContinueProofTitle,
            onPrimary: { openFeaturedVaultOrContinue() }
        )
    }

    @ViewBuilder
    private var vaultSecondaryTasks: some View {
        VStack(spacing: 10) {
            ProofTaskCard(
                title: "Lease & deposit records",
                reason: "Helps if your deposit is questioned later.",
                action: {
                    if let row = featuredPropertyRow {
                        openVaultDetail(for: row)
                    }
                }
            )
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
                title: "Add \(missing.displayTitle)",
                reason: "Helps if your deposit is questioned later.",
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

    private var vaultProofProgressHeadline: String {
        guard let prop = propertyStore.currentProperty else {
            let count = propertyStore.properties.count
            return count == 1 ? "1 vault" : "\(count) vaults"
        }
        let documented = propertyStore.documentedRoomCount(for: prop)
        let total = propertyStore.totalRoomCount(for: prop)
        if total == 0 {
            return "Add rooms to document damage"
        }
        if documented == 0 {
            return "Start with one room"
        }
        return "\(documented) of \(total) rooms ready"
    }

    private var vaultProofProgressValue: Double {
        guard let prop = propertyStore.currentProperty else { return 0 }
        let total = propertyStore.totalRoomCount(for: prop)
        guard total > 0 else { return 0 }
        let done = propertyStore.documentedRoomCount(for: prop)
        return Double(done) / Double(total)
    }

    private var featuredContinueProofTitle: String {
        guard let fid = featuredPropertyId,
              let prop = propertyStore.currentProperty, prop.id == fid else {
            return MMNextBestAction.continueProof.title
        }
        if propertyStore.documentedRoomCount(for: prop) == 0 {
            return "Start room proof"
        }
        switch propertyStore.primaryNextAction(for: prop) {
        case .captureRoom:
            return "Finish move-in proof"
        default:
            return MMNextBestActionMapper.from(
                propertyNextAction: propertyStore.primaryNextAction(for: prop)
            ).title
        }
    }

    private func openFeaturedVaultOrContinue() {
        guard let fid = featuredPropertyId,
              let row = propertyStore.properties.first(where: { $0.id == fid }) else { return }
        if let prop = propertyStore.currentProperty, prop.id == fid {
            switch propertyStore.primaryNextAction(for: prop) {
            case .captureRoom:
                path.append(.walkthrough)
            default:
                openVaultDetail(for: row)
            }
        } else {
            openVaultDetail(for: row)
        }
    }

    private var vaultContextPhaseLine: String {
        if let activeId = propertyStore.activePropertyId,
           let prop = propertyStore.currentProperty, prop.id == activeId {
            return propertyStore.proofWorkspaceHeadline(for: prop)
        }
        if propertyStore.activePropertyId != nil {
            return "Open this vault below to load live proof state"
        }
        return "Choose a vault below to continue your proof trail"
    }

    private var vaultContextNextLine: String? {
        guard let activeId = propertyStore.activePropertyId,
              let prop = propertyStore.currentProperty, prop.id == activeId else { return nil }
        return cleanedNextLine(propertyStore.primaryNextAction(for: prop).title)
    }

    /// One clear next step — avoid repeating phase + next on the hero card.
    private var vaultHeroNextLine: String {
        guard let next = vaultContextNextLine, !next.isEmpty else {
            return vaultContextPhaseLine
        }
        let phase = vaultContextPhaseLine
        if phase == next || phase.localizedCaseInsensitiveContains(next) {
            return next
        }
        if next.localizedCaseInsensitiveContains(phase) {
            return next
        }
        return next
    }

    private func cleanedNextLine(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("next:") {
            return String(t.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
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

    // MARK: - Empty / Loading

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardStack) {
                MMProofSectionHeader(
                    title: "Your proof",
                    subtitle: "What rental needs proof next?"
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
