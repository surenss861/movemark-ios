//
//  AuthContainerView.swift
//  movemork
//
//  MoveMark — One premium auth surface. Morph between create/sign in.
//

import SwiftUI

struct AuthContainerView: View {
    enum Mode {
        case signIn
        case signUp
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SessionManager.self) private var sessionManager

    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false
    @State private var hasAcceptedLegal = false

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

    init(initialMode: Mode) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            MMEmeraldBackground(emphasizesCTABloom: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock
                    trustChip
                        .padding(.bottom, 14)
                    authPanel
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.vertical, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textOnDark)
                        .frame(width: 42, height: 42)
                        .background(MoveMarkTheme.Colors.deepCard.opacity(0.9))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Image("MoveMarkLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .accessibilityHidden(true)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(mode == .signIn ? "Welcome back" : "Create your account")
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .tracking(-0.6)
                    .foregroundStyle(MoveMarkTheme.Colors.textOnDark)

                Text(
                    mode == .signIn
                        ? "Pick up where your proof trail left off."
                        : "Start building your proof trail."
                )
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textOnDarkMuted)
            }
        }
        .padding(.bottom, 8)
    }

    private var trustChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
            Text("Your proof stays private.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textOnDark)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MoveMarkTheme.Colors.deepCard.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.22), lineWidth: 1)
        )
    }

    private var authPanel: some View {
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

                if mode == .signUp {
                    legalConsentSection
                }

                modeSwitchRow
            }
        }
    }

    private var modeSwitchRow: some View {
        HStack(spacing: 6) {
            Text(mode == .signIn ? "Don't have an account?" : "Already have an account?")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    mode = mode == .signIn ? .signUp : .signIn
                    errorMessage = ""
                    infoMessage = ""
                    if mode == .signIn {
                        confirmPassword = ""
                        hasAcceptedLegal = false
                    }
                }
            } label: {
                Text(mode == .signIn ? "Create account" : "Sign in")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .font(MoveMarkTheme.Typography.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.95))

            HStack(alignment: .top, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        hasAcceptedLegal.toggle()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hasAcceptedLegal ? MoveMarkTheme.Colors.primary.opacity(0.18) : MoveMarkTheme.Colors.mint.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        hasAcceptedLegal ? MoveMarkTheme.Colors.primary.opacity(0.5) : MoveMarkTheme.Colors.panelStroke,
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
                        .font(.system(size: 14))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        Button("Terms of Use") {
                            if let termsURL { openURL(termsURL) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Button("Privacy Policy") {
                            if let privacyPolicyURL { openURL(privacyPolicyURL) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    }

                    Text("Required to create a MoveMark account.")
                        .font(.system(size: 12))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))

                    Text("MoveMark is a renter documentation tool and does not provide legal advice.")
                        .font(.system(size: 12))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MoveMarkTheme.Colors.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
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
