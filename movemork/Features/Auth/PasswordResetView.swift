//
//  PasswordResetView.swift
//  movemork
//
//  Set a new password from a reset link (`movemark://reset-password?token=…`).
//

import SwiftUI

enum PasswordResetLink {
    struct Token: Identifiable, Equatable {
        let value: String
        var id: String { value }
    }

    /// The token from `movemark://reset-password?token=…`, or nil for any other URL.
    static func token(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "movemark", url.host?.lowercased() == "reset-password",
              let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty
        else { return nil }
        return token
    }
}

struct PasswordResetView: View {
    @Environment(SessionManager.self) private var sessionManager

    let token: String
    let onDone: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var didReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.panelPadding) {
                Text(didReset ? "Password updated" : "Choose a new password")
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if didReset {
                    Text("Sign in with your new password.")
                        .font(MoveMarkTheme.Typography.body)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    MMButton(title: "Done", action: onDone, kind: .primary, size: .auth, isDisabled: false)
                        .accessibilityIdentifier("passwordReset.done")
                } else {
                    MMTextField(title: "New password", placeholder: "At least 8 characters", text: $password, isSecure: true, density: .authCompact)
                        .accessibilityIdentifier("passwordReset.password")
                    MMTextField(title: "Confirm password", placeholder: "Same as above", text: $confirmPassword, isSecure: true, density: .authCompact)
                        .accessibilityIdentifier("passwordReset.confirm")

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                            .accessibilityIdentifier("passwordReset.error")
                    }

                    MMButton(title: "Save new password", action: save, kind: .primary, size: .auth, isDisabled: isSaving)
                        .opacity(isSaving ? 0.6 : 1)
                        .accessibilityIdentifier("passwordReset.save")
                    Button("Cancel", action: onDone)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.vertical, MoveMarkTheme.Spacing.screenHorizontal)
        }
        .background(MoveMarkTheme.Colors.appBackground.ignoresSafeArea())
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = ""
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await sessionManager.completePasswordReset(token: token, newPassword: password, confirmPassword: confirmPassword)
                didReset = true
            } catch {
                errorMessage = MoveMarkFlowMessage.authOperationFailed(error)
            }
        }
    }
}
