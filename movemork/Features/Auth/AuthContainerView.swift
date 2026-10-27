//
//  AuthContainerView.swift
//  movemork
//
//  Sign in / create account — "your evidence has a private home". Dark header (title, close) over the light
//  working sheet: fields, one lime action, the other mode quietly below. No feature cards, no persuasion.
//  Password reset is reachable only from its deep link (PasswordResetView): email delivery is deferred, so
//  there is no "Forgot password?" here that would send a mail that can't arrive.
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
    private enum Field: Hashable { case email, password, confirm }
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    /// Set when sign-up succeeded but Neon Auth wants the address confirmed first: the form is replaced by
    /// a "Check your email" state for this address.
    @State private var confirmationEmail: String? = nil
    @State private var isLoading = false
    @State private var surfaceAppeared = false
    @State private var formFieldsAppeared = false
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
        if confirmationEmail != nil { return "Check your email" }
        return mode == .signIn ? "Welcome back." : "Create your private vault"
    }

    private var headerSubtitle: String {
        if confirmationEmail != nil { return "One more step to finish your vault." }
        return mode == .signIn
            ? "Continue your proof vault."
            : "Your rental proof stays tied to your account."
    }

    init(initialMode: Mode, onDismiss: @escaping () -> Void = {}) {
        _mode = State(initialValue: initialMode)
        self.onDismiss = onDismiss
    }

    /// Snapshot tests only: the settled surface (no entrance), optionally with a status message showing.
    /// Production uses the init above.
    init(previewMode: Mode, error: String = "", info: String = "", confirmationEmail: String? = nil) {
        self.init(initialMode: previewMode)
        _surfaceAppeared = State(initialValue: true)
        _formFieldsAppeared = State(initialValue: true)
        _errorMessage = State(initialValue: error)
        _infoMessage = State(initialValue: info)
        _confirmationEmail = State(initialValue: confirmationEmail)
    }

    var body: some View {
        MMScreen(
            title: headerTitle,
            subtitle: headerSubtitle,
            tail: 32 + keyboardBottomInset
        ) {
            dismissButton
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if let confirmationEmail {
                    MMResolvedBlock(
                        icon: "envelope",
                        title: "Check your email",
                        message: "We sent a confirmation link to \(confirmationEmail). Open it to finish creating your vault.",
                        actionTitle: "Back to sign in",
                        action: backToSignInAfterConfirmation
                    )
                    .accessibilityIdentifier("auth.confirmation")
                    .padding(.top, 4)
                } else {
                    authForm
                        .opacity(formFieldsAppeared ? 1 : 0)
                        .offset(y: formFieldsAppeared ? 0 : 8)
                }
            }
            .animation(authSpring, value: mode)
            .animation(authSpring, value: confirmationEmail)
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
            formFieldsAppeared = true
            return
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
            surfaceAppeared = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.9)) {
                formFieldsAppeared = true
            }
        }
    }

    // MARK: - Header

    /// Closes the surface back to Welcome. It sits in the header's trailing slot: the surface rises from
    /// the bottom like a sheet, so it closes like one.
    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityLabel("Back")
        .accessibilityIdentifier("auth.dismiss")
    }

    // MARK: - Form

    private var authForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            authInputFields

            authStatusMessages

            primaryActionButton
                .padding(.top, 22)

            if mode == .signUp {
                legalFinePrint
                    .padding(.top, 14)
                    .transition(fieldTransition)
            }

            modeSwitchRow
                .padding(.top, mode == .signUp ? 6 : 10)
        }
    }

    private var authInputFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            MMField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                keyboard: .emailAddress,
                autocapitalization: .never,
                accessibilityID: "auth.email",
                submitLabel: .next,
                onSubmit: { focusedField = .password }
            )
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)

            // Return signs in (or moves on): the primary action can sit under the keyboard on smaller phones.
            MMField(
                title: "Password",
                placeholder: mode == .signIn ? "Your password" : "At least 8 characters",
                text: $password,
                isSecure: true,
                accessibilityID: "auth.password",
                submitLabel: mode == .signIn ? .go : .next,
                onSubmit: { if mode == .signIn { submit() } else { focusedField = .confirm } }
            )
            .focused($focusedField, equals: .password)

            if mode == .signUp {
                MMField(
                    title: "Confirm password",
                    placeholder: "Same as above",
                    text: $confirmPassword,
                    isSecure: true,
                    accessibilityID: "auth.confirmPassword",
                    submitLabel: .go,
                    onSubmit: { submit() }
                )
                .focused($focusedField, equals: .confirm)
                .transition(fieldTransition)
            }
        }
    }

    @ViewBuilder
    private var authStatusMessages: some View {
        if !infoMessage.isEmpty || !errorMessage.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !infoMessage.isEmpty {
                    MMNotice(message: infoMessage, tone: .info)
                }
                if !errorMessage.isEmpty {
                    MMNotice(message: errorMessage)
                }
            }
            .padding(.top, 18)
        }
    }

    private var primaryActionButton: some View {
        MMPrimaryButton(
            title: mode == .signIn ? "Continue" : "Create vault",
            isLoading: isLoading
        ) { submit() }
        .accessibilityIdentifier("auth.primaryAction")
    }

    private var fieldTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .bottom))
    }

    /// One line when it fits; prompt above the action at large text sizes.
    private var modeSwitchRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                modeSwitchPrompt
                modeSwitchButton
            }
            VStack(spacing: 0) {
                modeSwitchPrompt.padding(.top, 8)
                modeSwitchButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var modeSwitchPrompt: some View {
        Text(mode == .signIn ? "New to MoveMark?" : "Already have a vault?")
            .mmFont(14)
            .foregroundStyle(MMInk.secondary)
            .multilineTextAlignment(.center)
    }

    private var modeSwitchButton: some View {
        MMTextAction(title: mode == .signIn ? "Create private vault" : "Sign in") {
            switchAuthMode()
        }
        .accessibilityIdentifier("auth.switchMode")
    }

    private var legalFinePrint: some View {
        Text(legalAttributedLine)
            .mmFont(12)
            .foregroundStyle(MMInk.secondary)
            .tint(MMInk.text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalAttributedLine: AttributedString {
        var line = AttributedString("By continuing, you agree to ")
        var terms = AttributedString("Terms")
        terms.foregroundColor = MMInk.text
        terms.underlineStyle = .single
        terms.link = termsURL
        let and = AttributedString(" and ")
        var privacy = AttributedString("Privacy")
        privacy.foregroundColor = MMInk.text
        privacy.underlineStyle = .single
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

    /// Leaves the confirmation state for sign-in with the address already filled in.
    private func backToSignInAfterConfirmation() {
        let update = {
            if let confirmationEmail { email = confirmationEmail }
            confirmationEmail = nil
            mode = .signIn
            password = ""
            confirmPassword = ""
            errorMessage = ""
            infoMessage = ""
        }
        if reduceMotion { update() } else { withAnimation(authSpring) { update() } }
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
                    // No session means no account to route into yet. The phase stays
                    // `.signedOut`, so this surface remains up and says why.
                    if result == .emailConfirmationRequired {
                        focusedField = nil
                        confirmationEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
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
