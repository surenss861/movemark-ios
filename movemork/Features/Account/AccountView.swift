//
//  AccountView.swift
//  movemork
//
//  MoveMark — Account: grouped rows, quiet cards, compact actions.
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
    @State private var subscriptionRestoreError: String? = nil

    private static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private var displayName: String {
        let name = sessionManager.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Add your name" : name
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
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
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardStack) {
                    MMProofSectionHeader(
                        title: "Account",
                        subtitle: "Manage your profile, plan, and proof vaults."
                    )
                    profileCard
                    planSection
                    privacySupportSection
                    securityCard
                    aboutCard

                    MMButton(
                        title: "Sign out",
                        action: {
                            propertyStore.clear()
                            Task { await sessionManager.signOut() }
                        },
                        kind: .secondary,
                        size: .standard
                    )

                    if rootTabBarVisible {
                        MMSignedInScrollTailSpacer(kind: .accountTab)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .mmScrollContentTopInset(2)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
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

    private var planSection: some View {
        accountSection(title: "Plan") {
            if let err = subscriptionManager.userFacingPlansErrorMessage, !err.isEmpty {
                MMErrorBanner(
                    message: err,
                    retryTitle: MMCopy.tryAgain,
                    onRetry: {
                        Task { @MainActor in
                            await subscriptionManager.refresh()
                        }
                    }
                )
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionManager.hasPro ? "MoveMark Pro" : "Free")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(planSummaryText)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                MMPill(
                    text: subscriptionManager.hasPro ? "Active" : "Current",
                    tone: .neutral
                )
            }

            if !subscriptionManager.hasPro {
                MMButton(
                    title: "Upgrade to Pro",
                    action: {
                        subscriptionRestoreFeedback = nil
                        subscriptionRestoreError = nil
                        showPaywall = true
                    },
                    kind: .secondary,
                    size: .standard
                )
                .padding(.top, 4)
            }
        }
    }

    private func runSubscriptionRestore() {
        subscriptionRestoreFeedback = nil
        subscriptionRestoreError = nil

        Task { @MainActor in
            do {
                try await subscriptionManager.restorePurchases()
                if subscriptionManager.hasPro {
                    subscriptionRestoreFeedback = "MoveMark Pro is active on this Apple ID."
                } else {
                    subscriptionRestoreFeedback =
                        "No active MoveMark subscription was found for this Apple ID. If you subscribed with a different Apple ID, use Subscriptions in App Store or sign into that account in Settings."
                }
            } catch {
                subscriptionRestoreError = MoveMarkFlowMessage.subscriptionRestoreFailed(error)
            }
        }
    }

    private var planSummaryText: String {
        if subscriptionManager.hasPro {
            return "More reports, move-out proof, and dispute tools."
        } else {
            return "1 property. 1 move-in report."
        }
    }

    private var profileCard: some View {
        accountSection(title: "Profile") {
            infoRow(label: "Name", value: displayName)

            Divider()
                .background(Color.white.opacity(0.08))

            infoRow(
                label: "Email",
                value: sessionManager.userEmail.isEmpty ? "—" : sessionManager.userEmail
            )

            MMButton(
                title: "Edit name",
                action: { showEditName = true },
                kind: .quiet,
                size: .compact
            )
            .padding(.top, 4)
        }
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .padding(.leading, 2)

            MMProofListRow(
                title: "Reset password",
                subtitle: "Send a reset link to your email",
                meta: isSendingReset ? "Sending…" : nil,
                onTap: { sendPasswordReset() }
            )

            if let resetMessage {
                Text(resetMessage)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                    .padding(.horizontal, 4)
            }

            if let resetError {
                MMErrorBanner(message: resetError)
            }
        }
    }

    private var aboutCard: some View {
        accountSection(title: "About") {
            infoRow(label: "App version", value: appVersion)

            Text("MoveMark helps renters document proof and records. It does not provide legal advice.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacySupportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy & support")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .padding(.leading, 2)

            VStack(spacing: 8) {
                MMProofListRow(
                    title: subscriptionManager.isLoading ? "Restoring purchases…" : "Restore purchases",
                    subtitle: "Sync MoveMark Pro with this Apple ID",
                    style: .settings,
                    onTap: { runSubscriptionRestore() }
                )
                .disabled(subscriptionManager.isLoading)

                MMProofListRow(
                    title: "Subscriptions in App Store",
                    subtitle: "View or cancel Apple subscriptions",
                    style: .settings,
                    onTap: { openURL(Self.appleSubscriptionsURL) }
                )

                settingsLinkRow(title: "Privacy Policy", subtitle: "View privacy policy", url: privacyPolicyURL)
                settingsLinkRow(title: "Terms of Use", subtitle: "View terms", url: termsURL)
                settingsLinkRow(title: "Contact Support", subtitle: "Get help", url: supportURL ?? supportEmailURL)
                settingsLinkRow(
                    title: "Account & Data Deletion",
                    subtitle: "Request deletion",
                    url: accountDeletionURL
                )
            }

            if let subscriptionRestoreFeedback {
                Text(subscriptionRestoreFeedback)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            if let subscriptionRestoreError {
                MMErrorBanner(message: subscriptionRestoreError, retryTitle: nil, onRetry: nil)
            }
        }
    }

    private func settingsLinkRow(title: String, subtitle: String, url: URL?) -> some View {
        MMProofListRow(
            title: title,
            subtitle: url == nil ? "Link not configured in this build" : subtitle,
            style: .settings,
            onTap: {
                guard let url else { return }
                openURL(url)
            }
        )
        .opacity(url == nil ? 0.55 : 1)
        .disabled(url == nil)
    }

    private func accountSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mmProofCardSurface(.standard, cornerRadius: 18)
        }
    }

    private func accountRow(
        label: String,
        value: String,
        emphasizeValue: Bool = true,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Text(value)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(
                        emphasizeValue
                            ? MoveMarkTheme.Colors.textPrimary
                            : MoveMarkTheme.Colors.textSecondary
                    )
            }

            Spacer()

            MMButton(
                title: actionTitle,
                action: action,
                kind: .quiet,
                size: .compact,
                expandsToFillWidth: false
            )
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                .multilineTextAlignment(.trailing)
        }
    }

    private func accountActionLinkRow(title: String, subtitle: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        disabled
                            ? MoveMarkTheme.Colors.textSecondary.opacity(0.35)
                            : MoveMarkTheme.Colors.primary
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func legalLinkRow(title: String, subtitle: String, url: URL?) -> some View {
        Button {
            guard let url else { return }
            openURL(url)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        url == nil
                            ? MoveMarkTheme.Colors.textSecondary.opacity(0.5)
                            : MoveMarkTheme.Colors.primary
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
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
