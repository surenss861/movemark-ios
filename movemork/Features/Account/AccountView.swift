//
//  AccountView.swift
//  movemork
//
//  MoveMark — quiet native account settings.
//

import SwiftUI

struct AccountView: View {
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showEditName = false
    @State private var showPaywall = false
    @State private var resetMessage: String? = nil
    @State private var resetError: String? = nil
    @State private var isSendingReset = false
    @State private var subscriptionRestoreFeedback: String? = nil
    @State private var contentAppeared = false

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

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MMProofSectionHeader(
                        title: "Account",
                        subtitle: "Manage your profile, plan, and proof vaults."
                    )
                    .mmAppearRise(isVisible: contentAppeared, delay: 0, offset: 6)

                    profileSection
                    planSection
                    privacySupportSection
                    securitySection
                    aboutSection
                    signOutSection

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
        .onAppear {
            if !contentAppeared { contentAppeared = true }
        }
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
                    action: nil
                )

                MMSettingsDivider()

                MMSettingsRow(
                    title: "Email",
                    accessory: .value(
                        sessionManager.userEmail.isEmpty ? "—" : sessionManager.userEmail
                    ),
                    action: nil
                )

                MMSettingsDivider()

                MMSettingsRow(
                    title: "Edit name",
                    subtitle: "Update how your name appears",
                    action: { showEditName = true }
                )
            }
        }
        .mmAppearRise(isVisible: contentAppeared, delay: 0.04, offset: 6)
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
                    title: subscriptionManager.hasPro ? "MoveMark Pro" : "MoveMark Free",
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
                        subtitle: "Unlimited vaults, reports, and dispute tools",
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
        .mmAppearRise(isVisible: contentAppeared, delay: 0.08, offset: 6)
    }

    private var planStatusSummary: String {
        if subscriptionManager.hasPro {
            return "Unlimited vaults, reports, move-out proof, and dispute tools."
        }
        return "1 proof vault · 1 move-in report"
    }

    // MARK: - Privacy & support

    private var privacySupportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "Privacy & support")

            MMSettingsGroup {
                settingsLinkRow(
                    title: "Privacy Policy",
                    subtitle: "How we handle your data",
                    url: privacyPolicyURL
                )
                MMSettingsDivider()
                settingsLinkRow(
                    title: "Terms of Use",
                    subtitle: "Subscription and service terms",
                    url: termsURL
                )
                MMSettingsDivider()
                settingsLinkRow(
                    title: "Contact Support",
                    subtitle: "Get help with your account",
                    url: supportURL ?? supportEmailURL
                )
                MMSettingsDivider()
                settingsLinkRow(
                    title: "Account & Data Deletion",
                    subtitle: "Request account removal",
                    url: accountDeletionURL
                )
            }
        }
        .mmAppearRise(isVisible: contentAppeared, delay: 0.12, offset: 6)
    }

    private func settingsLinkRow(title: String, subtitle: String, url: URL?) -> some View {
        MMSettingsRow(
            title: title,
            subtitle: url == nil ? "Not configured in this build" : subtitle,
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
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }

            if let resetError {
                Text(resetError)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticDanger.opacity(0.92))
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .mmAppearRise(isVisible: contentAppeared, delay: 0.16, offset: 6)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSettingsSectionHeader(title: "About")

            MMSettingsGroup {
                MMSettingsRow(
                    title: "App version",
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
        .mmAppearRise(isVisible: contentAppeared, delay: 0.2, offset: 6)
    }

    // MARK: - Sign out

    private var signOutSection: some View {
        MMSettingsGroup {
            MMSettingsRow(
                title: "Sign out",
                subtitle: "Clear this device and return to Welcome",
                action: {
                    propertyStore.clear()
                    Task { await sessionManager.signOut() }
                }
            )
        }
        .mmAppearRise(isVisible: contentAppeared, delay: 0.24, offset: 6)
    }

    // MARK: - Legal URLs

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

    // MARK: - Actions

    private func runSubscriptionRestore() {
        subscriptionRestoreFeedback = nil

        Task { @MainActor in
            let restored = await subscriptionManager.restorePurchases()
            if restored, subscriptionManager.hasPro {
                subscriptionRestoreFeedback = "MoveMark Pro is active on this Apple ID."
            } else if let err = subscriptionManager.lastRestoreErrorMessage {
                subscriptionRestoreFeedback = err
            } else {
                subscriptionRestoreFeedback =
                    "No active MoveMark subscription was found for this Apple ID."
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
            resetError = "No email on file for this account."
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
                    Text(errorMessage)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.semanticDanger.opacity(0.92))
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
