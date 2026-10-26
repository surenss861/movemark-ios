//
//  AuthContainerView.swift
//  movemork
//
//  MoveMark — minimal production auth for the private proof vault.
//

import SwiftUI
import UIKit

struct AuthContainerView: View {
    enum Mode: Equatable {
        case signIn
        case signUp
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionManager.self) private var sessionManager

    let onDismiss: () -> Void

    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false
    @State private var appeared = false
    @State private var keyboardBottomInset: CGFloat = 0

    private var privacyPolicyURL: URL? {
        legalURL(forInfoKey: "LegalPrivacyPolicyURL")
    }

    private var termsURL: URL? {
        legalURL(forInfoKey: "LegalTermsURL")
    }

    private var authAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.24)
    }

    private var title: String {
        mode == .signIn ? "Welcome back." : "Create your private vault."
    }

    private var subtitle: String {
        mode == .signIn
            ? "Sign in to continue your rental proof."
            : "Keep room evidence, supporting records, and reports under one account."
    }

    init(initialMode: Mode, onDismiss: @escaping () -> Void = {}) {
        _mode = State(initialValue: initialMode)
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .signIn ? "SIGN IN" : "PRIVATE VAULT")
                            .font(MoveMarkTheme.Typography.sectionLabel)
                            .tracking(0.9)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                        Text(title)
                            .font(MoveMarkTheme.Typography.pageTitle)
                            .tracking(-0.8)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(MoveMarkTheme.Typography.body)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 28)

                    if mode == .signUp {
                        trustRows
                            .padding(.top, 24)
                    }

                    form
                        .padding(.top, 26)

                    modeSwitchRow
                        .padding(.top, 18)

                    if mode == .signUp {
                        legalFinePrint
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.bottom, 32 + keyboardBottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.top, 8)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    appeared = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            applyKeyboardInset(from: note, visible: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            applyKeyboardInset(from: note, visible: false)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(MoveMarkTheme.Typography.button)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("auth.dismiss")

            Spacer()

            Text("MoveMark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.85))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var trustRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            trustRow("Room evidence stays organized by rental.")
            trustRow("Original source files are preserved when available.")
            trustRow("Reports are generated from the proof you save.")
        }
    }

    private func trustRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark")
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.primary)
                .frame(width: 18, height: 18)

            Text(text)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            MMTextField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                keyboardType: .emailAddress,
                density: .authCompact
            )
            .accessibilityIdentifier("auth.email")

            MMTextField(
                title: "Password",
                placeholder: mode == .signIn ? "Your password" : "At least 8 characters",
                text: $password,
                isSecure: true,
                density: .authCompact
            )
            .accessibilityIdentifier("auth.password")

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

            statusMessages

            ZStack {
                MMButton(
                    title: mode == .signIn ? "Sign in" : "Create private vault",
                    action: submit,
                    kind: .primary,
                    size: .auth,
                    isDisabled: isLoading
                )
                .opacity(isLoading ? 0.6 : 1)
                .accessibilityIdentifier("auth.primaryAction")

                if isLoading {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.textOnPrimary)
                }
            }
        }
        .animation(authAnimation, value: mode)
    }

    private var statusMessages: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !infoMessage.isEmpty {
                Text(infoMessage)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("auth.error")
            }
        }
    }

    private var modeSwitchRow: some View {
        HStack(spacing: 6) {
            Text(mode == .signIn ? "New to MoveMark?" : "Already have an account?")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Button {
                switchMode()
            } label: {
                Text(mode == .signIn ? "Create a private vault" : "Sign in")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.switchMode")
        }
        .font(MoveMarkTheme.Typography.subheadline)
        .frame(maxWidth: .infinity)
    }

    private var legalFinePrint: some View {
        Text(legalAttributedLine)
            .font(MoveMarkTheme.Typography.tiny)
            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var legalAttributedLine: AttributedString {
        var line = AttributedString("By continuing, you agree to ")
        var terms = AttributedString("Terms")
        terms.foregroundColor = MoveMarkTheme.Colors.primary
        terms.link = termsURL
        var and = AttributedString(" and ")
        var privacy = AttributedString("Privacy")
        privacy.foregroundColor = MoveMarkTheme.Colors.primary
        privacy.link = privacyPolicyURL
        line.append(terms)
        line.append(and)
        line.append(privacy)
        line.append(AttributedString("."))
        return line
    }

    private var fieldTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top))
    }

    private func switchMode() {
        let next: Mode = mode == .signIn ? .signUp : .signIn
        withAnimation(authAnimation) {
            mode = next
            errorMessage = ""
            infoMessage = ""
            if next == .signIn {
                confirmPassword = ""
            }
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
                    let result = try await sessionManager.signUp(
                        email: email,
                        password: password,
                        confirmPassword: confirmPassword
                    )
                    if result == .emailConfirmationRequired {
                        infoMessage = "Check your email to confirm your account, then sign in."
                    }
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
