//
//  DeleteAccountView.swift
//  movemork
//
//  In-app account deletion for App Store Guideline 5.1.1(v).
//

import Supabase
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
        let value = Bundle.main.object(forInfoDictionaryKey: "MoveMarkAPIBaseURL") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MMProofSectionHeader(
                        title: "Delete Account",
                        subtitle: "This cannot be undone."
                    )

                    warningCard

                    subscriptionCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.semanticDanger.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        MMButton(
                            title: isDeleting ? "Deleting…" : "Delete Account Permanently",
                            action: { showFinalConfirm = true },
                            kind: .primary,
                            size: .standard,
                            isDisabled: isDeleting
                        )

                        MMButton(
                            title: "Cancel",
                            action: { dismiss() },
                            kind: .secondary,
                            size: .standard,
                            isDisabled: isDeleting
                        )
                    }
                    .padding(.top, 8)

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Delete Account")
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

    private var warningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This permanently deletes your MoveMark account, proof vaults, reports, photos, and stored evidence.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.surface.opacity(0.92))
        )
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("If you have an active Apple subscription, deleting your account does not automatically cancel billing. You can manage or cancel your subscription through Apple.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openURL(Self.appleSubscriptionsURL)
            } label: {
                Text("Manage Apple Subscription")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.surface.opacity(0.72))
        )
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
            let session = try await supabase.auth.session
            let client = try ExportAPIClient(baseURLString: apiBaseURL)
            try await client.deleteAccount(accessToken: session.accessToken)

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
