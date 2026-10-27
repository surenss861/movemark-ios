//
//  PasswordResetView.swift
//  movemork
//
//  Set a new password from a reset link: the HTTPS Universal Link (`https://auth.<domain>/reset?token=…`)
//  or the `movemark://reset-password?token=…` scheme (the reset page's "Open in the app" button).
//

import SwiftUI

enum PasswordResetLink {
    struct Token: Identifiable, Equatable {
        let value: String
        var id: String { value }
    }

    /// The token from a reset link (the configured HTTPS reset page, or `movemark://reset-password`), or nil
    /// for any other URL.
    static func token(from url: URL, resetPage: URL? = MoveMarkBackendConfig.passwordResetURL) -> String? {
        let isScheme = url.scheme?.lowercased() == "movemark" && url.host?.lowercased() == "reset-password"
        let isPage = resetPage.map {
            url.scheme?.lowercased() == "https" && url.host?.lowercased() == $0.host?.lowercased() && url.path == $0.path
        } ?? false
        guard isScheme || isPage,
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
    private enum Field: Hashable { case password, confirm }
    @FocusState private var focusedField: Field?

    init(token: String, onDone: @escaping () -> Void) {
        self.token = token
        self.onDone = onDone
    }

    /// Snapshot tests only: open on the done or the failed state. Production uses the init above.
    init(token: String, previewDidReset: Bool, previewError: String = "", onDone: @escaping () -> Void = {}) {
        self.token = token
        self.onDone = onDone
        _didReset = State(initialValue: previewDidReset)
        _errorMessage = State(initialValue: previewError)
    }

    /// Entry's dark header (wordmark, title, close) over the light sheet — the same surface as sign in, so a
    /// reset link lands inside MoveMark rather than in a generic form. Reachable only from the link itself.
    var body: some View {
        MMScreen(
            title: didReset ? "Password updated" : "Choose a new password",
            subtitle: didReset ? "Sign in with your new password." : "Use at least 8 characters."
        ) {
            if !didReset {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .accessibilityLabel("Cancel")
                .accessibilityIdentifier("passwordReset.cancel")
                .disabled(isSaving)
            }
        } content: {
            if didReset {
                MMPrimaryButton(title: "Done", action: onDone)
                    .accessibilityIdentifier("passwordReset.done")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    MMField(title: "New password", placeholder: "At least 8 characters", text: $password,
                            isSecure: true, contentType: .newPassword, accessibilityID: "passwordReset.password",
                            submitLabel: .next, onSubmit: { focusedField = .confirm })
                        .focused($focusedField, equals: .password)
                    MMField(title: "Confirm password", placeholder: "Same as above", text: $confirmPassword,
                            isSecure: true, contentType: .newPassword, accessibilityID: "passwordReset.confirm",
                            submitLabel: .go, onSubmit: save)
                        .focused($focusedField, equals: .confirm)
                }

                if !errorMessage.isEmpty {
                    MMNotice(message: errorMessage)
                        .accessibilityIdentifier("passwordReset.error")
                        .padding(.top, 18)
                }

                MMPrimaryButton(title: "Save new password", isLoading: isSaving, action: save)
                    .accessibilityIdentifier("passwordReset.save")
                    .padding(.top, 22)
            }
        }
        .presentationBackground(MMInk.sheet)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard !isSaving else { return }
        focusedField = nil
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
