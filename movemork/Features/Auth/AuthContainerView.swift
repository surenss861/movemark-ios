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
        mode == .signIn ? "Welcome back." : "Create your proof vault"
    }

    private var headerSubtitle: String {
        mode == .signIn
            ? "Continue your proof vault."
            : "Save room photos, lease docs, and reports under one rental."
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
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock

                    titleBlock
                        .padding(.top, 14)
                        .padding(.bottom, 14)

                    proofSummarySection
                        .padding(.bottom, 14)
                        .opacity(surfaceAppeared ? 1 : 0)
                        .offset(y: surfaceAppeared ? 0 : 8)

                    authFormSection
                        .opacity(formFieldsAppeared ? 1 : 0)
                        .offset(y: formFieldsAppeared ? 0 : 8)

                    if mode == .signUp {
                        legalFinePrint
                            .padding(.top, 14)
                            .opacity(formFieldsAppeared ? 1 : 0)
                            .transition(fieldTransition)
                    }

                    if mode == .signUp {
                        modeSwitchRow
                            .padding(.top, 14)
                            .opacity(formFieldsAppeared ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.bottom, 24 + keyboardBottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.top, 10)
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

    private var headerBlock: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(MoveMarkTheme.Typography.button)
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

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image("MoveMarkLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)

                Text("MoveMark")
                    .font(MoveMarkTheme.Typography.button)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(headerTitle)
                .font(MoveMarkTheme.Typography.cardValue)
                .tracking(-0.4)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .id("auth-title-\(mode == .signIn ? "in" : "up")")

            Text(headerSubtitle)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
                .id("auth-subtitle-\(mode == .signIn ? "in" : "up")")
        }
        .animation(authSpring, value: mode)
    }

    // MARK: - Proof strip

    private var proofSummarySection: some View {
        AuthProofVaultStrip(mode: mode)
            .animation(authSpring, value: mode)
            .matchedGeometryEffect(id: "auth-proof-summary", in: authCardNamespace)
    }

    // MARK: - Form

    @ViewBuilder
    private var authFormSection: some View {
        if mode == .signUp {
            createFormSurface
        } else {
            signInFormSurface
        }
    }

    private var createFormSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            authInputFields
            authStatusMessages
            primaryActionButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(authSurfaceBackground(cornerRadius: 22, fillOpacity: 0.88))
        .matchedGeometryEffect(id: "auth-proof-form", in: authCardNamespace)
    }

    private var signInFormSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            authInputFields
            authStatusMessages
            primaryActionButton
            modeSwitchRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(authSurfaceBackground(cornerRadius: 22, fillOpacity: 0.78))
        .matchedGeometryEffect(id: "auth-proof-form", in: authCardNamespace)
    }

    private func authSurfaceBackground(cornerRadius: CGFloat, fillOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MoveMarkTheme.Colors.card.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.42), lineWidth: 0.75)
            )
    }

    private var authInputFields: some View {
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
        }
        .animation(authSpring, value: mode)
    }

    private var authStatusMessages: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        }
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
        .animation(authSpring, value: mode)
    }

    private var fieldTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .bottom))
    }

    private var modeSwitchRow: some View {
        HStack(spacing: 6) {
            Text(mode == .signIn ? "New to MoveMark?" : "Already have an account?")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Button {
                switchAuthMode()
            } label: {
                Text(mode == .signIn ? "Create private vault" : "Sign in")
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
            .font(MoveMarkTheme.Typography.tiny)
            .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.88))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
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
