//
//  SignedInRootView.swift
//  movemork
//
//  Gates signed-in users into first-run proof or the main tab shell.
//

import SwiftUI

struct SignedInRootView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore

    @State private var isRetrying = false

    var body: some View {
        Group {
            if !propertyStore.hasCompletedInitialFetch {
                MMLaunchWait()
            } else if shouldShowLoadFailure {
                PropertyLoadFailureView(
                    isRetrying: isRetrying,
                    onRetry: { Task { await retry() } },
                    onSignOut: { Task { await sessionManager.signOut() } }
                )
            } else if shouldShowFirstRunProof {
                FirstRunProofFlowView(requiresOnboarding: false)
            } else {
                AuthenticatedTabShellView()
            }
        }
        .task(id: sessionManager.userId) {
            await loadPropertiesIfNeeded()
        }
    }

    /// A failed load must never be mistaken for an empty account.
    ///
    /// `fetchAll` sets `hasCompletedInitialFetch` in a `defer`, so a thrown error still reaches the
    /// branches below with `properties` empty and `currentProperty` nil — which reads exactly like a
    /// brand-new user and would push an existing renter into first-run (and let them create a second
    /// property). `FirstRunProofPreferences` is device-local UserDefaults, so it does not catch this
    /// on a new device, a reinstall, or a restored backup.
    ///
    /// A cached snapshot is still trustworthy, so only block when there is nothing to show at all.
    private var shouldShowLoadFailure: Bool {
        propertyStore.lastFetchFailed && propertyStore.currentProperty == nil
    }

    private var shouldShowFirstRunProof: Bool {
        guard let userId = sessionManager.userId else { return false }
        if FirstRunProofPreferences.isComplete(userId: userId) { return false }
        if propertyStore.firstRunAwaitingReceiptDismissal { return true }
        if propertyStore.properties.isEmpty { return true }
        guard let property = propertyStore.currentProperty ?? hydratedFirstProperty else {
            return true
        }
        return propertyStore.documentedRoomCount(for: property) == 0
    }

    private var hydratedFirstProperty: PropertyRecord? {
        guard let id = propertyStore.properties.first?.id else { return nil }
        if propertyStore.currentProperty?.id == id { return propertyStore.currentProperty }
        return nil
    }

    private func loadPropertiesIfNeeded() async {
        guard let userId = sessionManager.userId else { return }
        if !propertyStore.hasCompletedInitialFetch {
            await propertyStore.fetchAll(userId: userId)
        }
        syncFirstRunCompletionFromExistingProof(userId: userId)
    }

    /// Explicit re-fetch: `loadPropertiesIfNeeded` is a no-op once the initial fetch has completed,
    /// and after a failure it has.
    private func retry() async {
        guard let userId = sessionManager.userId else { return }
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        await propertyStore.fetchAll(userId: userId)
        syncFirstRunCompletionFromExistingProof(userId: userId)
    }

    private func syncFirstRunCompletionFromExistingProof(userId: UUID) {
        guard !FirstRunProofPreferences.isComplete(userId: userId) else { return }
        guard let property = propertyStore.currentProperty else { return }
        if propertyStore.documentedRoomCount(for: property) > 0 {
            FirstRunProofPreferences.markComplete(userId: userId)
        }
    }
}

// MARK: - Recoverable load failure

/// Authentication succeeded; only the property load failed. The user stays signed in, and the copy never
/// implies the proof is gone — it is stored; it just couldn't be reached.
struct PropertyLoadFailureView: View {
    let isRetrying: Bool
    let onRetry: () -> Void
    var onSignOut: () -> Void = {}

    var body: some View {
        MMScreen(
            title: "Your vault couldn’t load",
            subtitle: "Your proof is still stored. MoveMark couldn’t reach it right now."
        ) {
            MMPrimaryButton(
                title: isRetrying ? "Trying again…" : "Try again",
                isLoading: isRetrying,
                action: onRetry
            )
            .accessibilityIdentifier("loadFailure.retry")

            Text("Check your connection and try again.")
                .mmFont(13.5)
                .foregroundStyle(MMInk.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            MMSecondaryButton(title: "Sign out", tint: MMInk.secondary, isDisabled: isRetrying, action: onSignOut)
                .accessibilityIdentifier("loadFailure.signOut")
                .padding(.top, 18)
        }
    }
}
