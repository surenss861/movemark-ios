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
    let termsURL: URL?
    let privacyURL: URL?
    /// The age statement to confirm; `nil` when the server requires one this build doesn't know (update the app).
    var age: LegalAgeRequirement? = .thirteenQuebecFourteen
    /// The chosen range for the age-range question (nil for the single-box statements).
    var onAccept: (LegalAgeBand?) async -> String? = { _ in nil }
    var onSignOut: () -> Void = {}
    var onDeleteAccount: () -> Void = {}

    @State private var agreed = false
    @State private var ageConfirmed = false
    @State private var ageChoice: LegalAgeChoice?
    @State private var livesInQuebec: Bool?
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
        .onChange(of: age) { _, _ in  // a changed statement needs a fresh answer
            ageConfirmed = false
            ageChoice = nil
            livesInQuebec = nil
        }
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MoveMark")
                .mmFont(15, .semibold)
                .foregroundStyle(MMInk.heroSecondary)
            Text("One last thing.")
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
            Text("Before you start protecting your rental, please review and agree to our terms.")
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

            ageConfirmation

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
        checkbox("I agree to the Terms of Service and acknowledge the Privacy Policy.", isOn: agreed, identifier: "legal.agree") {
            agreed.toggle()
        }
    }

    /// Mandatory, separate from the terms box, and unticked. No date of birth. Someone who can't confirm it stops here,
    /// with sign-out and deletion below; nothing suggests changing the answer.
    @ViewBuilder
    private var ageConfirmation: some View {
        if age == .ageRange {
            ageRangeQuestion
        } else if let age {
            VStack(alignment: .leading, spacing: 8) {
                checkbox(age.confirmation, isOn: ageConfirmed, identifier: "legal.age") { ageConfirmed.toggle() }
                Text(age.explanation)
                    .mmFont(13)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 34)
            }
        } else {
            MMEvidenceNotice(message: "Update MoveMark from the App Store to continue.")
                .environment(\.mmEvidenceOnLight, true)
        }
    }

    private func checkbox(_ text: String, isOn: Bool, identifier: String, toggle: @escaping () -> Void) -> some View {
        Button {
            MMHaptics.selection()
            toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(MMInk.text)
                    .accessibilityHidden(true)
                Text(text)
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
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isOn ? "Checked" : "Not checked")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Both boxes, a known age statement, and nothing in flight.
    /// The range to record, when the answer is an eligible one.
    var chosenBand: LegalAgeBand? { ageChoice?.band(livesInQuebec: livesInQuebec) }

    var canContinue: Bool {
        guard agreed, !isSaving, let age else { return false }
        return age == .ageRange ? chosenBand != nil : ageConfirmed
    }

    /// One question, four plain answers, nothing pre-selected, no date of birth. Under 13, and 13 in Quebec, get a
    /// clear "not available yet" with sign-out and deletion below; nothing suggests changing the answer.
    private var ageRangeQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LegalAgeRequirement.ageRange.confirmation)
                .mmFont(15, .semibold)
                .foregroundStyle(MMInk.text)
            ForEach(LegalAgeChoice.allCases, id: \.self) { choice in
                radio(choice.label, isOn: ageChoice == choice, identifier: "legal.age.\(choice.rawValue)") {
                    ageChoice = choice
                    if choice != .thirteen { livesInQuebec = nil }
                }
            }
            if ageChoice == .thirteen {
                Text("Do you live in Quebec?")
                    .mmFont(15, .semibold)
                    .foregroundStyle(MMInk.text)
                    .padding(.top, 4)
                HStack(spacing: 20) {
                    radio("Yes", isOn: livesInQuebec == true, identifier: "legal.age.quebec.yes") { livesInQuebec = true }
                    radio("No", isOn: livesInQuebec == false, identifier: "legal.age.quebec.no") { livesInQuebec = false }
                }
            }
            if let ageChoice, ageChoice.isUnavailable(livesInQuebec: livesInQuebec) {
                MMEvidenceNotice(message: "MoveMark isn’t available for you yet. We’re working on a way for a parent or guardian to set it up with you. You can sign out or delete this account below.")
                    .environment(\.mmEvidenceOnLight, true)
                    .accessibilityIdentifier("legal.age.unavailable")
            } else if chosenBand == .teen {
                Text("Because you’re under 18, photos you add are saved without their location or camera details. Your records are stored in the United States, nobody else sees them unless you share a report, and you can delete everything from Account at any time.")
                    .mmFont(13)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("legal.age.teenNotice")
            } else {
                Text(LegalAgeRequirement.ageRange.explanation)
                    .mmFont(13)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func radio(_ text: String, isOn: Bool, identifier: String, select: @escaping () -> Void) -> some View {
        Button {
            MMHaptics.selection()
            select()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(MMInk.text)
                    .accessibilityHidden(true)
                Text(text).mmFont(15).foregroundStyle(MMInk.text)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    private var actions: some View {
        VStack(spacing: 4) {
            MMPrimaryButton(title: "Continue to my Vault", isLoading: isSaving, isDisabled: !canContinue) { accept() }
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
        guard canContinue else { return }
        errorMessage = nil
        isSaving = true
        Task { @MainActor in
            errorMessage = await onAccept(chosenBand)
            isSaving = false
        }
    }
}

extension SessionManager {
    /// Everything the gate screen needs, already wired to this session.
    @MainActor
    func legalAcceptanceScreen(onDeleteAccount: @escaping () -> Void) -> LegalAcceptanceScreen {
        LegalAcceptanceScreen(
            termsURL: legalDocumentURL(\.terms, infoKey: "LegalTermsURL"),
            privacyURL: legalDocumentURL(\.privacyNotice, infoKey: "LegalPrivacyPolicyURL"),
            age: legalStatus.map(\.age) ?? .thirteenQuebecFourteen,
            onAccept: { band in await self.acceptLegalDocuments(band: band) },
            onSignOut: { Task { await self.signOut() } },
            onDeleteAccount: onDeleteAccount
        )
    }

    private func legalDocumentURL(_ document: KeyPath<LegalDocuments, LegalDocument>, infoKey: String) -> URL? {
        if let raw = legalStatus?.documents?[keyPath: document].url, let url = URL(string: raw) { return url }
        return (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String).flatMap(URL.init(string:))
    }
}
