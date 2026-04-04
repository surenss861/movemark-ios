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

            case .misconfigured:
                SupabaseMisconfigurationView()

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
            if phase == .signedOut || phase == .misconfigured {
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

// MARK: - Misconfiguration

private struct SupabaseMisconfigurationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.panelPadding) {
                Text("Can’t connect to MoveMark")
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(
                    "This build is missing a valid Supabase URL or anon key (often from an unset or mis-merged Secrets.xcconfig). The app won’t crash, but sign-in and sync won’t work until you fix the app target’s build settings."
                )
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Text("Developers: copy Config/Secrets.xcconfig.example to Secrets.xcconfig, set SUPABASE_URL (split https:// in xcconfig if needed) and SUPABASE_ANON_KEY, then clean and rebuild.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.vertical, MoveMarkTheme.Spacing.screenHorizontal)
        }
    }
}
