//
//  AuthenticatedTabShellView.swift
//  movemork
//
//  Root tabs (Vaults / Exports / Account) with tab bar only when appropriate:
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
                withAnimation(MMMotion.screenTransition) { selectedTab = new }
            }
        )
    }

    var body: some View {
        // Tab bar only at root; VStack reserves its height only when visible so task screens use full vertical space.
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .vaults:
                    AuthenticatedShellView(path: $vaultPath)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: -12)),
                            removal: .opacity.combined(with: .offset(x: 8))
                        ))
                case .exports:
                    NavigationStack {
                        ExportHistoryView(showOpenVaultsCTA: true, onOpenVaults: { selectedTab = .vaults })
                            .navigationTitle("")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 14)),
                        removal: .opacity.combined(with: .offset(x: -8))
                    ))
                case .account:
                    NavigationStack {
                        AccountView()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 14)),
                        removal: .opacity.combined(with: .offset(x: -8))
                    ))
                }
            }
            .animation(MMMotion.screenTransition, value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.mmRootTabBarVisible, showsRootTabBar)

            if showsRootTabBar {
                MMTabBar(selectedTab: selectedTabBinding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: showsRootTabBar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
