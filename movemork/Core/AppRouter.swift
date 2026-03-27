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

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            switch sessionManager.authPhase {
            case .loading:
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)

            case .signedOut:
                WelcomeScreen()

            case .needsOnboarding:
                OnboardingNameScreen()

            case .signedIn:
                AuthenticatedTabShellView()
            }
        }
        /// Single place that clears property context whenever auth ends — not only manual sign-out from Account.
        .onChange(of: sessionManager.authPhase) { _, phase in
            if phase == .signedOut {
                propertyStore.clear()
            }
        }
        .task(id: sessionManager.userId) {
            await subscriptionManager.syncAuth(
                appUserID: sessionManager.userId?.uuidString
            )
        }
    }
}
