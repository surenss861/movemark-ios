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
                VStack(alignment: .leading, spacing: 22) {
                    MMEditorialHeader(
                        eyebrow: "Settings",
                        title: "Account",
                        subtitle: "Plan, profile, and access to your proof vaults."
                    )
                    profileCard
                    subscriptionCard
                    legalCard
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
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .mmScrollContentTopInset(2)
                .padding(
                    .bottom,
                    rootTabBarVisible
                        ? MoveMarkTheme.Spacing.scrollTailRootTabChrome
                        : MoveMarkTheme.Spacing.scrollTailFocusedFlow
                )
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

    private var subscriptionCard: some View {
        accountSection(title: "Subscription") {
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

            if subscriptionManager.hasPro {
                proProductCard
            } else {
                freeProductCard
                proProductCard
            }

            VStack(alignment: .leading, spacing: 6) {
                subscriptionBenefitRow(subscriptionManager.hasPro ? "More property vaults" : "1 property vault")
                subscriptionBenefitRow(
                    subscriptionManager.hasPro
                        ? "More move-in and move-out reports"
                        : subscriptionManager.remainingFreeMoveInExportsText(forUser: sessionManager.userId)
                )
                subscriptionBenefitRow(subscriptionManager.hasPro ? "Move-out proof included" : "Move-out proof needs Pro")
                subscriptionBenefitRow(subscriptionManager.hasPro ? "Dispute tools included" : "Dispute tools need Pro")
            }
            if let subscriptionRestoreFeedback {
                Text(subscriptionRestoreFeedback)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.limeAccent.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let subscriptionRestoreError {
                MMErrorBanner(message: subscriptionRestoreError, retryTitle: nil, onRetry: nil)
            }

            Button {
                openURL(Self.appleSubscriptionsURL)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subscriptions in App Store")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Text("View, change, or cancel Apple subscriptions for this Apple ID.")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if subscriptionManager.hasPro {
                MMButton(
                    title: subscriptionManager.isLoading ? "Refreshing…" : "Restore purchases",
                    action: { runSubscriptionRestore() },
                    kind: .secondary,
                    size: .standard,
                    isDisabled: subscriptionManager.isLoading
                )
            } else {
                VStack(spacing: 10) {
                    MMButton(
                        title: "Upgrade to Pro",
                        action: {
                            subscriptionRestoreFeedback = nil
                            subscriptionRestoreError = nil
                            showPaywall = true
                        },
                        kind: .primary,
                        size: .standard
                    )

                    MMButton(
                        title: subscriptionManager.isLoading ? "Restoring…" : "Restore purchases",
                        action: { runSubscriptionRestore() },
                        kind: .secondary,
                        size: .standard,
                        isDisabled: subscriptionManager.isLoading
                    )
                }
            }
        }
    }

    private var freeProductCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Free")
                    .font(MoveMarkTheme.Typography.sectionTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Spacer()
                MMPill(text: subscriptionManager.hasPro ? "Included" : "Current", tone: subscriptionManager.hasPro ? .neutral : .warning)
            }
            Text("1 property · 1 move-in report")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmProofCardSurface(.standard, cornerRadius: 18)
        .opacity(subscriptionManager.hasPro ? 0.72 : 1)
    }

    private var proProductCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pro")
                    .font(MoveMarkTheme.Typography.sectionTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Spacer()
                if subscriptionManager.hasPro {
                    MMPill(text: "Active", tone: .success)
                } else {
                    MMPill(text: "Recommended", tone: .success)
                }
            }

            Text("Unlimited reports, move-out proof, and dispute tools.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmProofCardSurface(.depositPayoff, cornerRadius: 18)
        .shadow(color: Color.black.opacity(0.28), radius: 12, y: 5)
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

    private func subscriptionBenefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(MoveMarkTheme.Colors.primary)
                .padding(.top, 2)

            Text(text)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private var profileCard: some View {
        accountSection(title: "Profile") {
            accountRow(
                label: "Full name",
                value: displayName,
                emphasizeValue: displayName != "Add your name",
                actionTitle: "Edit",
                action: { showEditName = true }
            )

            Divider()
                .background(MoveMarkTheme.Colors.divider.opacity(0.22))

            infoRow(
                label: "Email",
                value: sessionManager.userEmail.isEmpty ? "—" : sessionManager.userEmail
            )
        }
    }

    private var securityCard: some View {
        accountSection(title: "Security") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                        Text("Send a reset link to your email")
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.84))
                    }

                    Spacer()

                    MMButton(
                        title: isSendingReset ? "Sending…" : "Reset",
                        action: { sendPasswordReset() },
                        kind: .quiet,
                        size: .compact,
                        isDisabled: isSendingReset,
                        expandsToFillWidth: false
                    )
                }

                if let resetMessage {
                    Text(resetMessage)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }

                if let resetError {
                    MMErrorBanner(message: resetError)
                }
            }
        }
    }

    private var aboutCard: some View {
        accountSection(title: "About") {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(
                    label: "App version",
                    value: appVersion
                )

                Text("MoveMark helps renters document proof and records. It does not provide legal advice.")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var legalCard: some View {
        accountSection(title: "Privacy, terms & subscriptions") {
            VStack(alignment: .leading, spacing: 10) {
                accountActionLinkRow(
                    title: subscriptionManager.isLoading ? "Restore purchases…" : "Restore purchases",
                    subtitle: "Sync MoveMark Pro with this Apple ID (same as the Upgrade screen).",
                    action: { runSubscriptionRestore() },
                    disabled: subscriptionManager.isLoading
                )

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                legalLinkRow(
                    title: "Subscriptions in App Store",
                    subtitle: "View, change, or cancel Apple subscriptions for this Apple ID.",
                    url: Self.appleSubscriptionsURL
                )

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                legalLinkRow(
                    title: "Privacy Policy",
                    subtitle: "How MoveMark collects, uses, and protects your data.",
                    url: privacyPolicyURL
                )

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                legalLinkRow(
                    title: "Terms of Use",
                    subtitle: "Subscriptions, user content, and rules for using MoveMark.",
                    url: termsURL
                )

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                legalLinkRow(
                    title: "Contact Support",
                    subtitle: "Get help with account, subscription, exports, or uploads.",
                    url: supportURL ?? supportEmailURL
                )

                Divider()
                    .background(MoveMarkTheme.Colors.divider.opacity(0.22))

                legalLinkRow(
                    title: "Account & Data Deletion",
                    subtitle: "How to request account and associated data deletion.",
                    url: accountDeletionURL
                )
            }
        }
    }

    private func accountSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        MMCard(tone: .elevated, padding: 18, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                content()
            }
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
