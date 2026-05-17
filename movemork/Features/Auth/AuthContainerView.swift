//
//  AuthContainerView.swift
//  movemork
//
//  Proof-first auth — save Welcome proof into a private vault.
//

import SwiftUI
import UIKit

struct AuthContainerView: View {
    enum Mode: Equatable {
        case signIn
        case signUp
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionManager.self) private var sessionManager

    @Namespace private var authCardNamespace

    let onDismiss: () -> Void

    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false
    @State private var surfaceAppeared = false
    @State private var keyboardBottomInset: CGFloat = 0

    private var privacyPolicyURL: URL? {
        legalURL(forInfoKey: "LegalPrivacyPolicyURL")
    }

    private var termsURL: URL? {
        legalURL(forInfoKey: "LegalTermsURL")
    }

    private var authSpring: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)
    }

    private var headerTitle: String {
        mode == .signIn ? "Welcome back." : "Start your move-in proof."
    }

    private var headerSubtitle: String {
        mode == .signIn
            ? "Continue your proof vault."
            : "Save this proof in a private vault."
    }

    init(initialMode: Mode, onDismiss: @escaping () -> Void = {}) {
        _mode = State(initialValue: initialMode)
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: false, ctaBloom: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerBlock
                    titleBlock
                    proofSummarySection
                    authFormSection

                    if mode == .signUp {
                        legalFinePrint
                            .transition(fieldTransition)
                    }

                    modeSwitchRow
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.bottom, 24 + keyboardBottomInset)
            }
            .safeAreaPadding(.top, 6)
            .scrollDismissesKeyboard(.interactively)
        }
        .offset(y: surfaceAppeared ? 0 : 28)
        .opacity(surfaceAppeared ? 1 : 0)
        .onAppear { playSurfaceEntrance() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            applyKeyboardInset(from: note, visible: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            applyKeyboardInset(from: note, visible: false)
        }
    }

    private func applyKeyboardInset(from note: Notification, visible: Bool) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let animation: Animation? = reduceMotion ? nil : .easeOut(duration: duration)

        withAnimation(animation) {
            if visible,
               let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardBottomInset = max(0, frame.height - 32)
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
        HStack(alignment: .center, spacing: 14) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(MoveMarkTheme.Colors.card.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.75), lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Image("MoveMarkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerTitle)
                .font(MoveMarkTheme.Typography.screenTitle)
                .tracking(-0.6)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .id("auth-title-\(mode == .signIn ? "in" : "up")")

            Text(headerSubtitle)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
                .id("auth-subtitle-\(mode == .signIn ? "in" : "up")")
        }
        .animation(authSpring, value: mode)
    }

    // MARK: - Proof receipt (stable across morph)

    private var proofSummarySection: some View {
        AuthProofSummaryCard(mode: mode)
            .animation(authSpring, value: mode)
            .matchedGeometryEffect(id: "auth-proof-summary", in: authCardNamespace)
    }

    // MARK: - Form

    @ViewBuilder
    private var authFormSection: some View {
        if mode == .signUp {
            createFormCard
        } else {
            signInFormStack
        }
    }

    private var createFormCard: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 10) {
            authFieldsStack
        }
        .matchedGeometryEffect(id: "auth-proof-form", in: authCardNamespace)
    }

    private var signInFormStack: some View {
        authFieldsStack
            .matchedGeometryEffect(id: "auth-proof-form", in: authCardNamespace)
    }

    private var authFieldsStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMTextField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                keyboardType: .emailAddress,
                density: .authCompact
            )

            MMTextField(
                title: "Password",
                placeholder: mode == .signIn ? "Your password" : "At least 6 characters",
                text: $password,
                isSecure: true,
                density: .authCompact
            )

            if mode == .signUp {
                MMTextField(
                    title: "Confirm password",
                    placeholder: "Same as above",
                    text: $confirmPassword,
                    isSecure: true,
                    density: .authCompact
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
                            .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
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

            primaryActionButton
                .padding(.top, 4)
                .animation(authSpring, value: mode)
        }
        .animation(authSpring, value: mode)
    }

    private var primaryActionButton: some View {
        ZStack {
            MMButton(
                title: mode == .signIn ? "Continue proof vault" : "Create private vault",
                action: { submit() },
                kind: .primary,
                size: .auth,
                isDisabled: isLoading
            )
            .opacity(isLoading ? 0.6 : 1.0)

            if isLoading {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
            }
        }
    }

    private var fieldTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .bottom))
    }

    private var modeSwitchRow: some View {
        HStack(spacing: 6) {
            Text(mode == .signIn ? "New to MoveMark?" : "Already have a vault?")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Button {
                switchAuthMode()
            } label: {
                Text(mode == .signIn ? "Create private vault" : "Continue proof vault")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
            }
            .buttonStyle(.plain)
        }
        .font(MoveMarkTheme.Typography.subheadline)
        .frame(maxWidth: .infinity)
    }

    private var legalFinePrint: some View {
        Text(legalAttributedLine)
            .font(.system(size: 11))
            .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.88))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var legalAttributedLine: AttributedString {
        var line = AttributedString("By continuing, you agree to ")
        var terms = AttributedString("Terms")
        terms.foregroundColor = MoveMarkTheme.Colors.primary.opacity(0.9)
        terms.link = termsURL
        var and = AttributedString(" and ")
        var privacy = AttributedString("Privacy")
        privacy.foregroundColor = MoveMarkTheme.Colors.primary.opacity(0.9)
        privacy.link = privacyPolicyURL
        line.append(terms)
        line.append(and)
        line.append(privacy)
        line.append(AttributedString("."))
        return line
    }

    private func switchAuthMode() {
        let next: Mode = mode == .signIn ? .signUp : .signIn
        if reduceMotion {
            mode = next
            errorMessage = ""
            infoMessage = ""
            if next == .signIn {
                confirmPassword = ""
            }
            return
        }
        withAnimation(authSpring) {
            mode = next
            errorMessage = ""
            infoMessage = ""
            if next == .signIn {
                confirmPassword = ""
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

    private func legalURL(forInfoKey key: String) -> URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
