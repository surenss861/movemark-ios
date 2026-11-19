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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showDeleteAccount = false
    @State private var passwordResetLink: PasswordResetLink.Payload?

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

            case .needsLegalAcceptance:
                sessionManager.legalAcceptanceScreen(onDeleteAccount: { showDeleteAccount = true })
                    .sheet(isPresented: $showDeleteAccount) {
                        NavigationStack { DeleteAccountView() }
                    }

            case .legalStatusUnavailable:
                LegalStatusUnavailableView(
                    onRetry: { await sessionManager.retryLegalStatus() },
                    onSignOut: { Task { await sessionManager.signOut() } }
                )

            case .needsOnboarding:
                FirstRunProofFlowView(requiresOnboarding: true)

            case .signedIn:
                SignedInRootView()
            }
        }
        .mmInAppLegalBrowser()
        /// Single place that clears property context whenever auth ends — not only manual sign-out from Account.
        .onOpenURL { url in
            if let link = PasswordResetLink.payload(from: url) {
                passwordResetLink = link
            }
        }
        .sheet(item: $passwordResetLink) { link in
            PasswordResetView(link: link) { nextAuthMode in
                passwordResetLink = nil
                guard let nextAuthMode else { return }
                // After the sheet starts down, so sign in rises over Welcome rather than under the sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(name: .moveMarkOpenAuth, object: nextAuthMode)
                }
            }
            .environment(sessionManager)
        }
        .onChange(of: scenePhase) { old, new in
            // Back from the background only: a permission alert or the app switcher (inactive) isn't a return.
            if old == .background, new == .active {
                Task { await sessionManager.recheckLegalStatus() }
            }
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

// MARK: - Legal status unavailable

/// The server answered the legal status with an error. Rare; one honest line, a retry and a way out.
struct LegalStatusUnavailableView: View {
    var onRetry: () async -> Void
    var onSignOut: () -> Void
    @State private var isRetrying = false

    var body: some View {
        MMScreen(
            title: "Can’t open your Vault yet",
            subtitle: "MoveMark couldn’t check your account just now. Your records are safe. Try again in a moment."
        ) {
            VStack(spacing: 8) {
                MMPrimaryButton(title: "Try again", isLoading: isRetrying, isDisabled: isRetrying) {
                    isRetrying = true
                    Task { @MainActor in
                        await onRetry()
                        isRetrying = false
                    }
                }
                .accessibilityIdentifier("legal.status.retry")
                Button("Sign out", action: onSignOut)
                    .mmFont(14, .medium)
                    .foregroundStyle(MMInk.secondary)
                    .frame(minHeight: 44)
                    .disabled(isRetrying)
            }
        }
    }
}

// MARK: - Misconfiguration

/// The build has no usable server address. Nothing to retry from here, so there is no primary action.
struct BackendMisconfigurationView: View {
    var body: some View {
        #if DEBUG
        MMScreen(
            title: "Can’t connect to MoveMark",
            subtitle: "This build is missing a valid MoveMark server address (often from an unset or mis-merged Secrets.xcconfig). The app won’t crash, but sign-in and sync won’t work until you fix the app target’s build settings."
        ) {
            MMNotice(
                message: "Developers: copy Config/Secrets.xcconfig.example to Secrets.xcconfig, set NEON_AUTH_URL and NEON_DATA_API_URL (split https:// in xcconfig), then clean and rebuild.",
                tone: .warning
            )
        }
        #else
        // Customers never see build instructions: one plain line.
        MMScreen(
            title: "Can’t connect to MoveMark",
            subtitle: "MoveMark can’t connect right now. Try again later."
        ) {
            EmptyView()
        }
        #endif
    }
}
