//
//  DeleteAccountView.swift
//  movemork
//
//  In-app account deletion for App Store Guideline 5.1.1(v).
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore

    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalConfirm = false

    private static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private var apiBaseURL: String? {
        MoveMarkBackendConfig.apiBaseURLString
    }

    var body: some View {
        DeleteAccountContent(
            isDeleting: isDeleting,
            errorMessage: errorMessage,
            onDelete: { showFinalConfirm = true },
            onCancel: { dismiss() },
            onManageSubscription: { openURL(Self.appleSubscriptionsURL) }
        )
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isDeleting)
        .confirmationDialog(
            "Delete your MoveMark account?",
            isPresented: $showFinalConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account, proof vaults, reports, photos, and stored evidence will be permanently deleted.")
        }
    }

    @MainActor
    private func performDeletion() async {
        guard !isDeleting else { return }
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            guard let apiBaseURL else {
                throw APIClientError.invalidBaseURL
            }
            let client = try ExportAPIClient(baseURLString: apiBaseURL)
            try await client.deleteAccount()
            // The account (and its Neon Auth identity) is gone; drop the session without a server round trip.
            await NeonAuthClient.shared.endSessionLocally(notify: false)

            propertyStore.clear()
            await sessionManager.signOut()
            dismiss()
        } catch {
            errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                error,
                fallback: "Couldn’t delete your account. Try again.",
                intent: .mutate
            )
            MMHaptics.error()
        }
    }
}
