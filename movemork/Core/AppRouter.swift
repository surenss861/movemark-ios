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
            MMInk.hero.ignoresSafeArea()

            switch sessionManager.authPhase {
            case .loading:
                MMLaunchWait()

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

/// The build has no usable server address. Nothing to retry from here, so there is no primary action.
struct BackendMisconfigurationView: View {
    var body: some View {
        MMScreen(
            title: "Can’t connect to MoveMark",
            subtitle: "This build is missing a valid MoveMark server address (often from an unset or mis-merged Secrets.xcconfig). The app won’t crash, but sign-in and sync won’t work until you fix the app target’s build settings.",
            tail: 360
        ) {
            MMNotice(
                message: "Developers: copy Config/Secrets.xcconfig.example to Secrets.xcconfig, set NEON_AUTH_URL and NEON_DATA_API_URL (split https:// in xcconfig), then clean and rebuild.",
                tone: .warning
            )
        }
    }
}
