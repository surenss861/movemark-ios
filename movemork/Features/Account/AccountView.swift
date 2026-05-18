//
//  AccountView.swift
//  movemork
//
//  MoveMark — quiet iOS-style account settings.
//

import SwiftUI

struct AccountView: View {
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible
    @Environment(\.openURL) private var openURL
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showEditName = false
    @State private var showPaywall = false
    @State private var resetMessage: String? = nil
    @State private var resetError: String? = nil
    @State private var isSendingReset = false
    @State private var subscriptionRestoreFeedback: String? = nil
    private static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private var displayName: String {
        let name = sessionManager.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Add your name" : name
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var privacyPolicyURL: URL? {
        legalURL(forInfoKey: "LegalPrivacyPolicyURL")
    }

    private var termsURL: URL? {
        legalURL(forInfoKey: "LegalTermsURL")
    }

    private var supportURL: URL? {
        legalURL(forInfoKey: "LegalSupportURL")
    }

    private var accountDeletionURL: URL? {
        legalURL(forInfoKey: "LegalAccountDeletionURL")
    }

    private var supportEmail: String {
        (Bundle.main.object(forInfoDictionaryKey: "LegalSupportEmail") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var supportEmailURL: URL? {
        guard !supportEmail.isEmpty else { return nil }
        return URL(string: "mailto:\(supportEmail)")
    }

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MMProofSectionHeader(
                        title: "Account",
                        subtitle: "Profile, plan, and app settings."
                    )

                    profileSection
                    planSection
                    privacySupportSection
                    securitySection
                    aboutSection

                    signOutButton

                    Color.clear
                        .frame(height: rootTabBarVisible
                            ? MoveMarkTheme.Spacing.scrollTailAccountTabChrome
                            : MoveMarkTheme.Spacing.scrollTailFocusedFlow)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .mmScrollContentTopInset(2)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: .extraProperty,
                onClose: { showPaywall = false }
            )
        }
        .sheet(isPresented: $showEditName) {
            EditNameSheet(
                currentName: sessionManager.firstName,
                onSave: { newName in
                    try sessionManager.updateProfileFullName(newName)
                }
            )
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "Profile")

            MMSettingsGroup {
                MMSettingsRow(
                    title: "Name",
                    accessory: .value(displayName),
                    action: { showEditName = true }
                )

                MMSettingsDivider()

                MMSettingsRow(
                    title: "Email",
                    accessory: .value(
                        sessionManager.userEmail.isEmpty ? "—" : sessionManager.userEmail
                    ),
                    action: nil
                )
            }
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(
                title: "Plan",
                footer: planStatusSummary
            )

            MMSettingsGroup {
                MMSettingsRow(
                    title: subscriptionManager.hasPro ? "MoveMark Pro" : "Free",
                    accessory: .pill(
                        subscriptionManager.hasPro ? "Active" : "Current",
                        subscriptionManager.hasPro ? .success : .neutral
                    ),
                    action: nil
                )

                if !subscriptionManager.hasPro {
                    MMSettingsDivider()

                    MMSettingsRow(
                        title: "Upgrade to Pro",
                        subtitle: "More properties and reports",
                        action: {
                            subscriptionRestoreFeedback = nil
                            showPaywall = true
                        }
                    )
                }

                if subscriptionManager.hasPro {
                    MMSettingsDivider()

                    MMSettingsRow(
                        title: "Manage subscription",
                        subtitle: "Apple subscriptions",
                        accessory: .external,
                        action: { openURL(Self.appleSubscriptionsURL) }
                    )
                }

                MMSettingsDivider()

                MMSettingsRow(
                    title: subscriptionManager.isLoading ? "Restoring purchases…" : "Restore purchases",
                    subtitle: "Sync MoveMark Pro with this Apple ID",
                    isDisabled: subscriptionManager.isLoading,
                    action: { runSubscriptionRestore() }
                )
            }

            if let subscriptionRestoreFeedback {
                Text(subscriptionRestoreFeedback)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }

    private var planStatusSummary: String {
        if subscriptionManager.hasPro {
            return subscriptionManager.accountPlanSummaryLine
        }
        return "1 property. 1 move-in report."
    }

    // MARK: - Privacy & support

    private var privacySupportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "Privacy & support")

            MMSettingsGroup {
                settingsLinkRow(title: "Privacy Policy", url: privacyPolicyURL)
                MMSettingsDivider()
                settingsLinkRow(title: "Terms of Use", url: termsURL)
                MMSettingsDivider()
                settingsLinkRow(title: "Contact Support", url: supportURL ?? supportEmailURL)
                MMSettingsDivider()
                settingsLinkRow(title: "Account & Data Deletion", url: accountDeletionURL)
            }
        }
    }

    private func settingsLinkRow(title: String, url: URL?) -> some View {
        MMSettingsRow(
            title: title,
            subtitle: url == nil ? "Not configured in this build" : nil,
            accessory: url == nil ? .none : .external,
            isDisabled: url == nil,
            action: {
                guard let url else { return }
                openURL(url)
            }
        )
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "Security")

            MMSettingsGroup {
                MMSettingsRow(
                    title: "Reset password",
                    subtitle: "Send a link to your email",
                    accessory: isSendingReset ? .value("Sending…") : .chevron,
                    isDisabled: isSendingReset,
                    action: { sendPasswordReset() }
                )
            }

            if let resetMessage {
                Text(resetMessage)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }

            if let resetError {
                MMErrorBanner(message: resetError)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "About")

            MMSettingsGroup {
                MMSettingsRow(
                    title: "Version",
                    accessory: .value(appVersion),
                    action: nil
                )
            }

            Text("MoveMark helps renters document proof and records. It does not provide legal advice.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            propertyStore.clear()
            Task { await sessionManager.signOut() }
        } label: {
            Text("Sign out")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .mmProofCardSurface(.neutral, cornerRadius: 14)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func runSubscriptionRestore() {
        subscriptionRestoreFeedback = nil

        Task { @MainActor in
            let restored = await subscriptionManager.restorePurchases()
            if restored, subscriptionManager.hasPro {
                subscriptionRestoreFeedback = "MoveMark Pro is active on this Apple ID."
            } else {
                subscriptionRestoreFeedback =
                    "No active MoveMark subscription was found for this Apple ID. If you subscribed with a different Apple ID, use Manage subscription or sign into that Apple ID in Settings."
            }
        }
    }

    private func legalURL(forInfoKey key: String) -> URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return url
    }

    private func sendPasswordReset() {
        let email = sessionManager.userEmail
        guard !email.isEmpty else {
            resetError = "No email on file."
            resetMessage = nil
            return
        }

        resetError = nil
        resetMessage = nil
        isSendingReset = true

        Task { @MainActor in
            defer { isSendingReset = false }
            do {
                try await sessionManager.sendPasswordReset(email: email)
                resetMessage = "Check your email for a link to reset your password."
            } catch {
                resetError = MoveMarkFlowMessage.accountPasswordResetFailed(error)
            }
        }
    }
}

private struct EditNameSheet: View {
    let currentName: String
    let onSave: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(currentName: String, onSave: @escaping (String) throws -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                MMTextField(title: "Full name", placeholder: "Enter your full name", text: $name)

                if let errorMessage {
                    MMErrorBanner(message: errorMessage)
                }
            }
            .padding()
            .navigationTitle("Edit name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveName()
                    }
                    .disabled(isSaving || trimmedName.isEmpty || trimmedName == currentName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
    }

    private func saveName() {
        let nextName = trimmedName
        guard !nextName.isEmpty else {
            errorMessage = "Enter your full name."
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try onSave(nextName)
            dismiss()
        } catch {
            errorMessage = MoveMarkFlowMessage.accountProfileUpdateFailed(error)
        }
    }
}
