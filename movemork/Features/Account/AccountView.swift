//
//  AccountView.swift
//  movemork
//
//  MoveMark — Account: session, plan (RevenueCat entitlement), restore, legal links and deletion.
//  ``AccountHomeView`` draws it.
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
    @State private var showDeleteAccount = false
    @State private var restoreFeedback: AccountHomeModel.Feedback? = nil
    /// Photos only on this iPhone (not uploaded yet) when Sign out was tapped; > 0 asks first.
    @State private var unsavedPhotoCount = 0
    @State private var confirmSignOut = false

    private static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var model: AccountHomeModel {
        let name = sessionManager.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return AccountHomeModel(
            email: sessionManager.userEmail,
            name: name.isEmpty ? nil : name,
            isPro: subscriptionManager.hasPro,
            isRestoring: subscriptionManager.isStoreKitBusy,
            restoreFeedback: restoreFeedback,
            hasSupport: supportURL != nil,
            hasPrivacyPolicy: privacyPolicyURL != nil,
            hasTerms: termsURL != nil,
            appVersion: appVersion
        )
    }

    var body: some View {
        AccountHomeView(model: model, onAction: perform)
            // At the root the dark header runs under the status bar; pushed, the back button sits on it.
            .toolbar(rootTabBarVisible ? .hidden : .automatic, for: .navigationBar)
            .toolbarBackground(AccountHomeView.headerColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                ProPaywallView(
                    reason: .account,
                    onClose: { showPaywall = false },
                    moveInRecorded: hasMoveInPhotos
                )
            }
            .sheet(isPresented: $showEditName) {
                EditNameSheet(
                    currentName: sessionManager.firstName,
                    onSave: { newName in
                        try await sessionManager.updateProfileFullName(newName)
                    }
                )
            }
            .confirmationDialog(
                unsavedPhotoCount == 1
                    ? "1 photo hasn’t been saved yet. Signing out removes it from this iPhone."
                    : "\(unsavedPhotoCount) photos haven’t been saved yet. Signing out removes them from this iPhone.",
                isPresented: $confirmSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showDeleteAccount) {
                NavigationStack {
                    DeleteAccountView()
                }
                .environment(sessionManager)
                .environment(propertyStore)
                .environment(subscriptionManager)
            }
    }

    private func perform(_ action: AccountHomeView.Action) {
        switch action {
        case .editName:
            showEditName = true
        case .subscription:
            restoreFeedback = nil
            if subscriptionManager.hasPro { openURL(Self.appleSubscriptionsURL) } else { showPaywall = true }
        case .restore:
            runSubscriptionRestore()
        case .support:
            if let supportURL { openURL(supportURL) }
        case .privacy:
            if let privacyPolicyURL { openURL(privacyPolicyURL) }
        case .terms:
            if let termsURL { openURL(termsURL) }
        case .signOut:
            guard let userId = sessionManager.userId else { signOut(); return }
            Task {
                unsavedPhotoCount = await PendingEvidenceCenter.shared.pendingCount(userId: userId)
                if unsavedPhotoCount > 0 { confirmSignOut = true } else { signOut() }
            }
        case .deleteAccount:
            showDeleteAccount = true
        }
    }

    /// Signing out on purpose clears this user's pending (not uploaded) photos from the phone.
    private func signOut() {
        let userId = sessionManager.userId
        propertyStore.clear()
        // Downloaded reports are personal records: they don't outlive the session on a shared iPhone.
        ReportFileDownloader.clearCache()
        Task {
            if let userId { await PendingEvidenceCenter.shared.clearUser(userId) }
            await sessionManager.signOut()
        }
    }

    /// The current rental already has move-in photos (paywall timeline's first step).
    private var hasMoveInPhotos: Bool {
        guard let property = propertyStore.currentProperty else { return false }
        return propertyStore.totalPhotoCount(for: property) > 0
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

    // MARK: - Actions

    private func runSubscriptionRestore() {
        restoreFeedback = nil

        Task { @MainActor in
            let restored = await subscriptionManager.restorePurchases(forUser: sessionManager.userId)
            if restored, subscriptionManager.hasPro {
                restoreFeedback = .init(message: "MoveMark Pro is active on this Apple ID.")
            } else if restored, subscriptionManager.hasUsableReportPackCredit(forUser: sessionManager.userId) {
                restoreFeedback = .init(message: "Report Pack credit restored on this Apple ID.")
            } else if let err = subscriptionManager.lastRestoreErrorMessage {
                restoreFeedback = .init(message: err, isError: true)
            } else {
                restoreFeedback = .init(message: "No active MoveMark subscription or Report Pack was found for this Apple ID.")
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
}

struct EditNameSheet: View {
    let currentName: String
    let onSave: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @FocusState private var fieldFocused: Bool
    @State private var confirmDiscard = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An edited name that closing the sheet would lose.
    private var hasChanges: Bool {
        trimmedName != currentName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && !trimmedName.isEmpty && trimmedName != currentName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `draftName` / `initialError` are snapshot seams for the error state; the app starts from the current name.
    init(currentName: String, onSave: @escaping (String) async throws -> Void, draftName: String? = nil, initialError: String? = nil) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: draftName ?? currentName)
        _errorMessage = State(initialValue: initialError)
    }

    var body: some View {
        NavigationStack {
            MMSheetScaffold(title: "") {
                VStack(alignment: .leading, spacing: 8) {
                    // Field label in the light-sheet style ("Room name", "Issue title").
                    Text("Your name")
                        .mmFont(13, .medium)
                        .foregroundStyle(MMInk.secondary)
                        .accessibilityHidden(true)
                    TextField("Full name", text: $name)
                        .mmFont(17)
                        .foregroundStyle(MMInk.text)
                        .tint(MMInk.text)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { if canSave { saveName() } }
                        .focused($fieldFocused)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(MMInk.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(errorMessage == nil ? MMInk.cardStroke : MMInk.danger.opacity(0.6), lineWidth: 1))
                        .accessibilityLabel("Your name")
                        .accessibilityIdentifier("Full name")
                    Text("Used on your MoveMark account.")
                        .mmFont(13)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                if let errorMessage {
                    MMNotice(message: errorMessage)
                        .padding(.top, 16)
                }

                MMPrimaryButton(title: isSaving ? "Saving…" : "Save", isLoading: isSaving, isDisabled: !canSave) {
                    saveName()
                }
                .padding(.top, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        MMDiscardChanges.cancel(hasChanges: hasChanges, isConfirming: $confirmDiscard, dismiss: { dismiss() })
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear { fieldFocused = true }
            .mmDiscardChangesGuard(hasChanges: hasChanges, isBusy: isSaving, isConfirming: $confirmDiscard,
                                   onDiscard: { dismiss() })
        }
    }

    private func saveName() {
        let nextName = trimmedName
        guard !nextName.isEmpty else {
            errorMessage = "Enter your full name."
            return
        }
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true

        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await onSave(nextName)
                dismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.accountProfileUpdateFailed(error)
            }
        }
    }
}
