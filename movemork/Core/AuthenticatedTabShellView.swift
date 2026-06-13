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

    private var showsRootTabBar: Bool {
        switch selectedTab {
        case .vaults:
            return vaultPath.isEmpty
        case .exports, .account:
            return true
        }
    }

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: { selectedTab },
            set: { new in
                guard new != selectedTab else { return }
                MMHaptics.selection()
                withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) {
                    selectedTab = new
                }
            }
        )
    }

    var body: some View {
        ZStack {
            tabContent
                .id(selectedTab)
                .transition(tabTransition)
                .animation(reduceMotion ? nil : MMMotion.tabSwitch, value: selectedTab)
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

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .vaults:
            AuthenticatedShellView(path: $vaultPath)
        case .exports:
            NavigationStack {
                ExportHistoryView(
                    showOpenVaultsCTA: true,
                    onOpenVaults: { selectedTab = .vaults },
                    onContinueRoomProof: {
                        selectedTab = .vaults
                        vaultPath = [.walkthrough]
                    },
                    onOpenMoveOutProof: {
                        selectedTab = .vaults
                        vaultPath = [.moveOut]
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

    private var tabTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: MMMotion.tabContentRise))
    }

    private func consumePendingFirstRunExit() {
        guard let exit = propertyStore.pendingFirstRunExit else { return }
        propertyStore.pendingFirstRunExit = nil
        selectedTab = .vaults
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
