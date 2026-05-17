//
//  AuthContainerView.swift
//  movemork
//
//  Proof-first auth — continuation of Welcome “Start move-in proof”.
//

import SwiftUI
import UIKit

struct AuthContainerView: View {
    enum Mode: Equatable {
        case signIn
        case signUp
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionManager.self) private var sessionManager

    @Namespace private var authCardNamespace

    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false
    @State private var hasAcceptedLegal = false
    @State private var surfaceAppeared = false
    @State private var keyboardBottomInset: CGFloat = 0

    private var privacyPolicyURL: URL? {
        legalURL(forInfoKey: "LegalPrivacyPolicyURL")
    }

    private var termsURL: URL? {
        legalURL(forInfoKey: "LegalTermsURL")
    }

    private var isSubmitDisabled: Bool {
        if mode == .signUp {
            return isLoading || !hasAcceptedLegal
        }
        return isLoading
    }

    private var authSpring: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private var headerTitle: String {
        mode == .signIn ? "Welcome back." : "Start your move-in proof."
    }

    private var headerSubtitle: String {
        mode == .signIn
            ? "Continue your proof vault."
            : "Save your photos, notes, lease, and reports in one private vault."
    }

    init(initialMode: Mode) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock
                    trustChip
                        .padding(.bottom, 14)
                    authProofCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 28 + keyboardBottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .offset(y: surfaceAppeared ? 0 : 24)
        .opacity(surfaceAppeared ? 1 : 0)
        .onAppear { playSurfaceEntrance() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            applyKeyboardInset(from: note, visible: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            applyKeyboardInset(from: note, visible: false)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func applyKeyboardInset(from note: Notification, visible: Bool) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let animation: Animation? = reduceMotion ? nil : .easeOut(duration: duration)

        withAnimation(animation) {
            if visible,
               let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardBottomInset = max(0, frame.height - 24)
            } else {
                keyboardBottomInset = 0
            }
        }
    }

    private func playSurfaceEntrance() {
        if reduceMotion {
            surfaceAppeared = true
            return
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
            surfaceAppeared = true
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(MoveMarkTheme.Colors.card.opacity(0.92))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.8), lineWidth: 0.85)
                        )
                }
                .buttonStyle(.plain)

                Image("MoveMarkLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(headerTitle)
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .tracking(-0.6)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("auth-title-\(mode == .signIn ? "in" : "up")")

                Text(headerSubtitle)
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
                    .id("auth-subtitle-\(mode == .signIn ? "in" : "up")")
            }
            .animation(authSpring, value: mode)
        }
        .padding(.bottom, 8)
    }

    private var trustChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary)
            Text("Your proof stays private.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.95))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MoveMarkTheme.Colors.card.opacity(0.88))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.primary.opacity(0.28), lineWidth: 0.85)
        )
    }

    // MARK: - Form card

    private var authProofCard: some View {
        MMCard(tone: .elevated, padding: 22, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                MMTextField(title: "Email", placeholder: "you@example.com", text: $email, keyboardType: .emailAddress)

                MMTextField(
                    title: "Password",
                    placeholder: mode == .signIn ? "Your password" : "At least 6 characters",
                    text: $password,
                    isSecure: true
                )

                if mode == .signUp {
                    MMTextField(
                        title: "Confirm password",
                        placeholder: "Same as above",
                        text: $confirmPassword,
                        isSecure: true
                    )
                    .transition(fieldTransition)
                }

                if mode == .signIn {
                    HStack {
                        Spacer()
                        Button {
                            Task { @MainActor in
                                await requestPasswordReset()
                            }
                        } label: {
                            Text("Forgot password?")
                                .font(MoveMarkTheme.Typography.footnote)
                                .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(fieldTransition)
                }

                if !infoMessage.isEmpty {
                    Text(infoMessage)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                }

                ZStack {
                    MMButton(
                        title: mode == .signIn ? "Sign in" : "Create account",
                        action: { submit() },
                        kind: .primary,
                        size: .hero,
                        isDisabled: isSubmitDisabled
                    )
                    .opacity(isSubmitDisabled ? 0.6 : 1.0)

                    if isLoading {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
                    }
                }
                .animation(authSpring, value: mode)

                if mode == .signUp {
                    legalConsentSection
                        .transition(fieldTransition)
                }

                modeSwitchRow
            }
            .animation(authSpring, value: mode)
        }
        .matchedGeometryEffect(id: "auth-proof-card", in: authCardNamespace)
    }

    private var fieldTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .bottom))
    }

    private var modeSwitchRow: some View {
        HStack(spacing: 6) {
            Text(mode == .signIn ? "Don't have an account?" : "Already have an account?")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Button {
                switchAuthMode()
            } label: {
                Text(mode == .signIn ? "Create account" : "Sign in")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
            }
            .buttonStyle(.plain)
        }
        .font(MoveMarkTheme.Typography.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func switchAuthMode() {
        let next: Mode = mode == .signIn ? .signUp : .signIn
        if reduceMotion {
            mode = next
            errorMessage = ""
            infoMessage = ""
            if next == .signIn {
                confirmPassword = ""
                hasAcceptedLegal = false
            }
            return
        }
        withAnimation(authSpring) {
            mode = next
            errorMessage = ""
            infoMessage = ""
            if next == .signIn {
                confirmPassword = ""
                hasAcceptedLegal = false
            }
        }
    }

    private func requestPasswordReset() async {
        guard mode == .signIn else { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        infoMessage = ""
        defer { isLoading = false }
        do {
            try await sessionManager.sendPasswordReset(email: email)
            infoMessage = "If an account exists for that email, you’ll get a reset link shortly."
        } catch {
            errorMessage = MoveMarkFlowMessage.authOperationFailed(error)
        }
    }

    private func submit() {
        guard !isLoading else { return }
        if mode == .signUp && !hasAcceptedLegal {
            errorMessage = "Please accept the Terms of Use and Privacy Policy."
            return
        }
        isLoading = true
        errorMessage = ""
        infoMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                switch mode {
                case .signIn:
                    try await sessionManager.signIn(email: email, password: password)
                case .signUp:
                    try await sessionManager.signUp(email: email, password: password, confirmPassword: confirmPassword)
                }
            } catch {
                errorMessage = MoveMarkFlowMessage.authOperationFailed(error)
            }
        }
    }

    private var legalConsentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))

            HStack(alignment: .top, spacing: 10) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        hasAcceptedLegal.toggle()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hasAcceptedLegal ? MoveMarkTheme.Colors.primary.opacity(0.18) : MoveMarkTheme.Colors.fieldFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        hasAcceptedLegal ? MoveMarkTheme.Colors.primary.opacity(0.5) : MoveMarkTheme.Colors.cardStroke,
                                        lineWidth: 1
                                    )
                            )
                            .frame(width: 22, height: 22)

                        if hasAcceptedLegal {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.96))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasAcceptedLegal ? "Accepted legal terms" : "Accept legal terms")

                VStack(alignment: .leading, spacing: 8) {
                    Text("I agree to the Terms of Use and acknowledge the Privacy Policy.")
                        .font(.system(size: 13))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        Button("Terms of Use") {
                            if let termsURL { openURL(termsURL) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.primary)

                        Button("Privacy Policy") {
                            if let privacyPolicyURL { openURL(privacyPolicyURL) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }

                    Text("MoveMark is a renter documentation tool and does not provide legal advice.")
                        .font(.system(size: 11))
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.65), lineWidth: 0.85)
                )
        )
    }

    private func legalURL(forInfoKey key: String) -> URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
