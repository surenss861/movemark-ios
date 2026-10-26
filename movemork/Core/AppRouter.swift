//
//  AppRouter.swift
//  movemork
//
//  MoveMark — Root routing based on auth phase.
//

import SwiftUI

struct AppRouter: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var passwordResetToken: PasswordResetLink.Token?

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            switch sessionManager.authPhase {
            case .loading:
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)

            case .misconfigured:
                BackendMisconfigurationView()

            case .signedOut:
                WelcomeScreen()

            case .needsOnboarding:
                FirstRunProofFlowView(requiresOnboarding: true)

            case .signedIn:
                SignedInRootView()
            }
        }
        /// Single place that clears property context whenever auth ends — not only manual sign-out from Account.
        .onOpenURL { url in
            if let token = PasswordResetLink.token(from: url) {
                passwordResetToken = PasswordResetLink.Token(value: token)
            }
        }
        .sheet(item: $passwordResetToken) { token in
            PasswordResetView(token: token.value) { passwordResetToken = nil }
                .environment(sessionManager)
        }
        .onChange(of: sessionManager.authPhase) { _, phase in
            if phase == .signedOut || phase == .misconfigured {
                propertyStore.clear()
            }
        }
        .task {
            subscriptionManager.configure(appUserID: sessionManager.revenueCatAppUserID)
        }
        .task(id: sessionManager.userId) {
            await subscriptionManager.syncAuth(
                appUserID: sessionManager.revenueCatAppUserID
            )
        }
    }
}

// MARK: - Misconfiguration

private struct BackendMisconfigurationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.panelPadding) {
                Text("Can’t connect to MoveMark")
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("This version of MoveMark can’t reach the service it needs for sign-in and sync. Your device data hasn’t been changed.")
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Try installing the latest version of MoveMark. If the problem continues, contact support.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                #if DEBUG
                Text("Developer detail: verify Secrets.xcconfig and the Neon Auth/Data API build settings, then clean and rebuild.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.vertical, MoveMarkTheme.Spacing.screenHorizontal)
        }
    }
}
