//
//  LegalAcceptanceScreen.swift
//  movemork
//
//  @file One deliberate step between sign-in and the Vault, for email, Apple and Google alike, and for existing
//        renters with no recorded acceptance. Short, honest and in the Vault's grammar: dark header, light sheet, one
//        lime action. The box starts unchecked. Declining keeps the documents, sign-out and account deletion in reach.
//  @domain onboarding-auth
//  @status wip
//  @see [[LegalGate.swift]]
//

import SwiftUI

struct LegalAcceptanceScreen: View {
    /// A new account hasn't started its Vault yet; an existing one is returning to it.
    let isNewAccount: Bool
    let termsURL: URL?
    let privacyURL: URL?
    var onAccept: () async -> String? = { nil }
    var onSignOut: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    @State private var agreed = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                sheet
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            VStack(spacing: 0) {
                MMInk.hero.frame(height: 320)
                MMInk.sheet
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MoveMark")
                .mmFont(15, .semibold)
                .foregroundStyle(MMInk.heroSecondary)
            Text(isNewAccount ? "Before we create your Vault." : "Before you continue.")
                .font(MoveMarkTheme.Typography.roomTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.hero)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your rental photos, documents and reports are private records. Here’s how MoveMark handles them.")
                .mmFont(16)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                document("Terms of Service", url: termsURL)
                Rectangle().fill(MMInk.separator).frame(height: 1).accessibilityHidden(true)
                document("Privacy Policy", url: privacyURL)
            }
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 1))

            agreement

            if let errorMessage {
                MMEvidenceNotice(message: errorMessage)
                    .environment(\.mmEvidenceOnLight, true)
            }
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(MMInk.sheet)
        )
        .padding(.top, -22)
    }

    @ViewBuilder
    private func document(_ title: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack {
                    Text(title).mmFont(16, .medium).foregroundStyle(MMInk.text)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MMInk.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .accessibilityHint("Opens in your browser")
        }
    }

    private var agreement: some View {
        Button {
            MMHaptics.selection()
            agreed.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(MMInk.text)
                    .accessibilityHidden(true)
                Text("I agree to MoveMark’s Terms of Service and acknowledge its Privacy Policy.")
                    .mmFont(15)
                    .foregroundStyle(MMInk.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("legal.agree")
        .accessibilityValue(agreed ? "Checked" : "Not checked")
        .accessibilityAddTraits(agreed ? .isSelected : [])
    }

    private var actions: some View {
        VStack(spacing: 4) {
            MMPrimaryButton(title: "Continue", isLoading: isSaving, isDisabled: !agreed || isSaving) { accept() }
                .accessibilityIdentifier("legal.continue")
            HStack(spacing: 20) {
                quiet("Sign out", action: onSignOut)
                quiet("Delete account", action: onDeleteAccount)
            }
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(MMInk.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(MMInk.cardStroke).frame(height: 0.5) }
    }

    private func quiet(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .mmFont(14, .medium)
                .foregroundStyle(MMInk.secondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func accept() {
        guard agreed, !isSaving else { return }
        errorMessage = nil
        isSaving = true
        Task { @MainActor in
            errorMessage = await onAccept()
            isSaving = false
        }
    }
}

extension SessionManager {
    /// Everything the gate screen needs, already wired to this session.
    @MainActor
    func legalAcceptanceScreen(onDeleteAccount: @escaping () -> Void) -> LegalAcceptanceScreen {
        LegalAcceptanceScreen(
            isNewAccount: legalGateIsNewAccount,
            termsURL: legalDocumentURL(\.terms, infoKey: "LegalTermsURL"),
            privacyURL: legalDocumentURL(\.privacyNotice, infoKey: "LegalPrivacyPolicyURL"),
            onAccept: { await self.acceptLegalDocuments() },
            onSignOut: { Task { await self.signOut() } },
            onDeleteAccount: onDeleteAccount
        )
    }

    private func legalDocumentURL(_ document: KeyPath<LegalDocuments, LegalDocument>, infoKey: String) -> URL? {
        if let raw = legalStatus?.documents?[keyPath: document].url, let url = URL(string: raw) { return url }
        return (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String).flatMap(URL.init(string:))
    }
}
