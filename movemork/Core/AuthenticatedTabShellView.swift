//
//  AuthenticatedTabShellView.swift
//  movemork
//
//  Root tabs (Proof / Reports / Account) with tab bar only when appropriate:
//  bar visible for vault stack root and for Exports & Account tabs; hidden for any vault push
//  (property detail, walkthrough, capture, move-out, dispute, etc.).
//

import SwiftUI

enum RootTab: Hashable {
    case vaults
    case exports
    case account
}

struct AuthenticatedTabShellView: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: RootTab = .vaults
    /// Vault-tab navigation only; non-empty means workspace/task screens — hide root tab bar.
    @State private var vaultPath: [AppRoute] = []
    /// Tabs stay alive once opened, so switching never rebuilds a page (scroll, loaded data and navigation
    /// survive) and the outgoing page stays solid under the incoming one instead of two half-faded screens.
    @State private var visitedTabs: Set<RootTab> = [.vaults]
    /// The page being left: kept visible underneath until the incoming page has resolved.
    @State private var outgoingTab: RootTab?
    /// The incoming page's settle (0 = in place).
    @State private var incomingRise: CGFloat = 0
    @State private var incomingOpacity: Double = 1
    @State private var transitionToken = 0

    private var showsRootTabBar: Bool {
        switch selectedTab {
        case .vaults:
            return vaultPath.isEmpty
        case .exports, .account:
            return true
        }
    }

    private var selectedTabBinding: Binding<RootTab> {
        Binding(get: { selectedTab }, set: { switchTo($0) })
    }

    var body: some View {
        ZStack {
            ForEach([RootTab.vaults, .exports, .account], id: \.self) { tab in
                if visitedTabs.contains(tab) {
                    page(for: tab)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.mmRootTabBarVisible, showsRootTabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsRootTabBar {
                MMProofTabBarV4(selectedTab: selectedTabBinding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsRootTabBar)
        .onAppear { consumePendingFirstRunExit() }
        .onChange(of: propertyStore.pendingFirstRunExit != nil) { _, hasPending in
            if hasPending { consumePendingFirstRunExit() }
        }
    }

    /// One root page. Only the selected page (and, mid-switch, the one being left) is visible, hit-testable
    /// and in the accessibility tree; the incoming page sits on top while it resolves.
    private func page(for tab: RootTab) -> some View {
        let isSelected = tab == selectedTab
        let isOutgoing = tab == outgoingTab
        return tabContent(tab)
            .opacity(isSelected ? incomingOpacity : (isOutgoing ? 1 : 0))
            .offset(y: isSelected ? incomingRise : 0)
            .zIndex(isSelected ? 2 : (isOutgoing ? 1 : 0))
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    /// Old tab stays put → the new page fades in over it with a small settle → the old page is hidden.
    /// The dock and the screen frame never move.
    private func switchTo(_ new: RootTab) {
        guard new != selectedTab else { return }
        let previous = selectedTab
        transitionToken += 1
        let token = transitionToken
        visitedTabs.insert(new)
        if new == .exports {
            // Reports was kept alive: refresh it quietly instead of rebuilding it.
            NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
        }
        var setup = Transaction()
        setup.disablesAnimations = true
        withTransaction(setup) {
            outgoingTab = previous
            selectedTab = new
            incomingOpacity = 0
            incomingRise = reduceMotion ? 0 : MMMotion.tabContentRise
        }
        withAnimation(reduceMotion ? MMMotion.tabContentFadeReduced : MMMotion.tabContentFade) {
            incomingOpacity = 1
            incomingRise = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard token == transitionToken else { return }
            outgoingTab = nil
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: RootTab) -> some View {
        switch tab {
        case .vaults:
            AuthenticatedShellView(path: $vaultPath)
        case .exports:
            NavigationStack {
                ExportHistoryView(
                    showOpenVaultsCTA: true,
                    onOpenVaults: { switchTo(.vaults) },
                    onContinueRoomProof: {
                        vaultPath = [.walkthrough]
                        switchTo(.vaults)
                    },
                    onOpenMoveOutProof: {
                        vaultPath = [.moveOut]
                        switchTo(.vaults)
                    },
                    onOpenDisputePacket: {
                        vaultPath = [.disputePacket]
                        switchTo(.vaults)
                    }
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            }
        case .account:
            NavigationStack {
                AccountView()
            }
        }
    }

    private func consumePendingFirstRunExit() {
        guard let exit = propertyStore.pendingFirstRunExit else { return }
        propertyStore.pendingFirstRunExit = nil
        if selectedTab != .vaults { switchTo(.vaults) }
        switch exit {
        case .continueNextRoom:
            vaultPath = [.walkthrough]
        case .viewVault:
            vaultPath = []
        }

        guard let userId = sessionManager.userId else { return }
        Task {
            _ = await propertyStore.refreshActivePropertyHydration(userId: userId)
        }
    }
}
