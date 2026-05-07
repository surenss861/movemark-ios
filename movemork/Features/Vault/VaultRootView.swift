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
    @Environment(\.vaultTransitionNamespace) private var vaultNamespace
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showAddProperty = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .extraProperty
    @State private var previewURLByPropertyId: [UUID: URL] = [:]
    @State private var hasAnimatedIn = false
    @State private var expandedVaultId: UUID? = nil

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

    private var vaultsDashboard: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    stagedHeader

                    if let error = propertyStore.errorMessage {
                        MMErrorBanner(
                            message: error,
                            retryTitle: MMCopy.tryAgain,
                            onRetry: { Task { await reload() } }
                        )
                    }

                    ForEach(Array(propertyStore.properties.enumerated()), id: \.element.id) { index, row in
                        VaultCoverCard(
                            model: coverCardModel(for: row),
                            expansion: row.id == featuredPropertyId ? expansionContent(for: row) : nil,
                            expandedVaultId: $expandedVaultId,
                            namespace: vaultNamespace,
                            onTap: { openVaultDetail(for: row) },
                            onPreviewImageFailure: {
                                Task { await loadPreviewURLs() }
                            }
                        )
                        .opacity(hasAnimatedIn ? 1 : 0)
                        .offset(y: hasAnimatedIn ? 0 : 18)
                        .animation(MMMotion.cardReveal.delay(0.12 + Double(index) * 0.05), value: hasAnimatedIn)
                    }

                    vaultHealthFooter
                        .opacity(hasAnimatedIn ? 1 : 0)
                        .offset(y: hasAnimatedIn ? 0 : 8)
                        .animation(.easeOut(duration: 0.35).delay(0.2), value: hasAnimatedIn)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .padding(
                    .bottom,
                    MoveMarkTheme.Spacing.scrollTailRootTabChrome
                        + (expandedVaultId != nil ? MoveMarkTheme.Spacing.vaultExpansionScrollExtra : 0)
                )
            }
            .scrollIndicators(.hidden, axes: .vertical)
            .background(MoveMarkTheme.Colors.background.ignoresSafeArea())
            .task {
                await loadPreviewURLs()
            }
            .task(id: featuredPropertyId) {
                await ensureFeaturedPropertyLoaded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadPreviewURLs() }
                }
            }
            .onAppear {
                guard !hasAnimatedIn else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    hasAnimatedIn = true
                }
            }

            FloatingAddButton {
                if subscriptionManager.canCreateProperty(currentCount: propertyStore.properties.count) {
                    showAddProperty = true
                } else {
                    activePaywallReason = .extraProperty
                    showPaywall = true
                }
            }
                .padding(.top, 8)
                .padding(.trailing, MoveMarkTheme.Spacing.screenHorizontal)
        }
    }

    /// Staged entrance: eyebrow → title → operational subhead → accent → system context strip.
    private var stagedHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MoveMark")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.accent)
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 8)
                .animation(.easeOut(duration: 0.4).delay(0), value: hasAnimatedIn)

            Text("Vaults")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 12)
                .blur(radius: hasAnimatedIn ? 0 : 6)
                .animation(.easeOut(duration: 0.45).delay(0.04), value: hasAnimatedIn)

            Text("Move-in proof, exports, and records — organized per rental.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.06), value: hasAnimatedIn)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: hasAnimatedIn ? 40 : 0, height: 3)
                .clipShape(Capsule())
                .animation(.easeOut(duration: 0.45).delay(0.08), value: hasAnimatedIn)

            vaultSystemContextStrip
                .opacity(hasAnimatedIn ? 1 : 0)
                .offset(y: hasAnimatedIn ? 0 : 8)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAnimatedIn)
        }
        .padding(.bottom, 4)
    }

    /// Inline system state — not a summary card; bridges hero → workspace.
    private var vaultSystemContextStrip: some View {
        MMCard(tone: .quiet, padding: 12, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(vaultContextStripTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("·")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.45))

                    Text(vaultContextWorkspaceName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.88))
                        .lineLimit(1)
                }

                Text(vaultContextPhaseLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)

                if let next = vaultContextNextLine {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(MoveMarkTheme.Colors.primary.opacity(0.9))
                            .frame(width: 4, height: 4)
                        Text(next)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.94))
                    }
                }
            }
        }
    }

    private var vaultContextStripTitle: String {
        let count = propertyStore.properties.count
        return count == 1 ? "1 vault" : "\(count) vaults"
    }

    private var vaultContextWorkspaceName: String {
        guard let activeId = propertyStore.activePropertyId,
              let active = propertyStore.properties.first(where: { $0.id == activeId }) else {
            return "No workspace"
        }
        return displayName(for: active)
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

    /// Secondary vaults: honest copy when we don’t have that property hydrated.
    private func secondaryStatusLine(for row: PropertyRow) -> String {
        if let prop = propertyStore.currentProperty, prop.id == row.id {
            return propertyStore.proofWorkspaceHeadline(for: prop)
        }
        return "Open for proof status, rooms, and next steps"
    }

    /// Top-right chip: Current for active property; Complete / In progress when we have data.
    private func statusChip(for row: PropertyRow) -> String? {
        if propertyStore.activePropertyId == row.id {
            return "Current"
        }

        guard let prop = propertyStore.currentProperty, prop.id == row.id else {
            switch fallbackStyle(for: row) {
            case .ready: return "Ready"
            case .started: return "In progress"
            case .empty: return "Open"
            }
        }

        let total = propertyStore.totalRoomCount(for: prop)
        guard total > 0 else { return nil }

        let documented = propertyStore.documentedRoomCount(for: prop)
        return documented == total ? "Complete" : "In progress"
    }

    /// Next action title from canonical store.
    private func nextAction(for row: PropertyRow) -> String? {
        guard let prop = propertyStore.currentProperty, prop.id == row.id else { return nil }
        return propertyStore.primaryNextAction(for: prop).title
    }

    /// Fallback cover style for empty / started / ready states.
    private func fallbackStyle(for row: PropertyRow) -> VaultFallbackStyle {
        guard let prop = propertyStore.currentProperty, prop.id == row.id else { return .empty }
        let total = prop.rooms.count
        guard total > 0 else { return .empty }
        let documented = prop.rooms.filter { !$0.evidence.isEmpty }.count
        if documented == total { return .ready }
        if documented > 0 { return .started }
        return .empty
    }

    /// Build model for VaultCoverCard from a property row. Only featured card gets chip + emphasis + product CTA.
    private func coverCardModel(for row: PropertyRow) -> VaultCoverCardModel {
        let isFeatured = row.id == featuredPropertyId
        let isCurrent = propertyStore.activePropertyId == row.id
        let next = nextAction(for: row)
        let prop = (propertyStore.currentProperty?.id == row.id) ? propertyStore.currentProperty : nil

        let workflow: String? = {
            if let p = prop { return propertyStore.proofWorkspaceHeadline(for: p) }
            if isCurrent { return "Open this vault to refresh live proof workflow" }
            return nil
        }()

        let metrics: String? = {
            if let p = prop {
                let line = propertyStore.compactProofMetricsLine(for: p)
                return line.isEmpty ? nil : line
            }
            return "Open to view proof status, rooms, and records."
        }()

        let bandStatusLine: String = {
            if isFeatured, let p = prop {
                return propertyStore.heroStatusLine(for: p)
            }
            return secondaryStatusLine(for: row)
        }()

        return VaultCoverCardModel(
            id: row.id,
            title: displayName(for: row),
            city: locationText(for: row),
            statusLine: bandStatusLine,
            workflowHeadline: workflow,
            proofMetricsLine: metrics,
            nextAction: isFeatured ? next : nil,
            ctaTitle: featuredCtaTitle(for: row),
            chipText: statusChip(for: row),
            previewImageURL: previewURLByPropertyId[row.id],
            fallbackStyle: fallbackStyle(for: row),
            isRecent: isCurrent,
            isEmphasized: isFeatured
        )
    }

    /// Short product-specific CTA for featured card from canonical store. Only used for featured cards.
    private func featuredCtaTitle(for row: PropertyRow) -> String {
        guard let prop = propertyStore.currentProperty, prop.id == row.id else { return "Open" }
        return propertyStore.primaryNextAction(for: prop).shortCTA
    }

    private var vaultHealthFooter: some View {
        MMCard(tone: .quiet, padding: 14, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vault health")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Text(vaultHealthLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var vaultHealthLine: String {
        guard let prop = propertyStore.currentProperty else {
            return "Open a vault to view proof progress, supporting records, and next recommended action."
        }
        let documented = propertyStore.documentedRoomCount(for: prop)
        let total = propertyStore.totalRoomCount(for: prop)
        let docs = prop.vaultDocuments.count
        let action = cleanedNextLine(propertyStore.primaryNextAction(for: prop).title)
        if total == 0 {
            return "\(docs) records uploaded · Next: \(action)"
        }
        return "\(documented)/\(total) rooms documented · \(docs) records uploaded · Next: \(action)"
    }

    private func cleanedNextLine(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("next:") {
            return String(t.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    /// Expansion tray data when we have full property (currentProperty). Nil for other rows. Uses store workflow.
    private func expansionContent(for row: PropertyRow) -> VaultCoverExpansionContent? {
        guard let prop = propertyStore.currentProperty, prop.id == row.id else { return nil }

        let documented = propertyStore.documentedRoomCount(for: prop)
        let total = propertyStore.totalRoomCount(for: prop)
        let openIssues = propertyStore.openIssueCount(for: prop)
        let nextRoom = propertyStore.nextRoomToCapture(for: prop)
        let progress = propertyStore.roomsCompletionProgress(for: prop)

        let roomsText = total == 0
            ? "No rooms yet"
            : "\(documented) of \(total) rooms documented"

        let openIssuesText = openIssues == 0
            ? "0 open issues"
            : openIssues == 1
                ? "1 open issue"
                : "\(openIssues) open issues"

        let nextRoomLine: String? = {
            guard let nextRoom, nextRoom.evidence.isEmpty else { return nil }
            return "Next room: \(nextRoom.name)"
        }()

        let nextAction = propertyStore.primaryNextAction(for: prop)

        let primaryActionTitle: String
        let onPrimaryAction: () -> Void

        switch nextAction {
        case .captureRoom:
            primaryActionTitle = "Continue walkthrough"
            onPrimaryAction = { path.append(.walkthrough) }

        case .uploadDocument:
            primaryActionTitle = "Open vault"
            onPrimaryAction = { openVaultDetail(for: row) }

        case .reviewMaintenance:
            primaryActionTitle = "Review issues"
            onPrimaryAction = { path.append(.maintenance) }

        case .openDisputeBuilder:
            primaryActionTitle = "Open dispute builder"
            onPrimaryAction = { path.append(.disputeBuilder) }

        case .openExports:
            primaryActionTitle = "Open exports"
            onPrimaryAction = { path.append(.exports) }

        case .reviewVault:
            primaryActionTitle = "Open vault"
            onPrimaryAction = { openVaultDetail(for: row) }
        }

        return VaultCoverExpansionContent(
            roomsText: roomsText,
            openIssuesText: openIssuesText,
            lastUpdated: nil,
            nextRoomLine: nextRoomLine,
            progress: progress,
            primaryActionTitle: primaryActionTitle,
            onPrimaryAction: onPrimaryAction
        )
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
            VStack(alignment: .leading, spacing: 24) {
                vaultHeader

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
                        message: "Create a property vault for your rental, then run the move-in walkthrough room by room. Everything you save stays organized for exports and disputes.",
                        primaryTitle: "Add property",
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
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 18)
            .padding(.bottom, MoveMarkTheme.Spacing.scrollTailRootTabChrome)
        }
        .background(MoveMarkTheme.Colors.background.ignoresSafeArea())
    }

    private var vaultHeader: some View {
        MMEditorialHeader(
            eyebrow: "MoveMark",
            title: "Vault",
            subtitle: "Your renter proof system starts here."
        )
    }

    private var loadingState: some View {
        MMLoadingState(message: MMCopy.loadingProofTrail)
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
