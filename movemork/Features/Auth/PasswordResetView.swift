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

    var body: some View {
        NavigationStack {
            MMSheetScaffold(title: didReset ? "Password updated" : "Choose a new password") {
                if didReset {
                    Text("Sign in with your new password.")
                        .mmFont(15)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    MMPrimaryButton(title: "Done", action: onDone)
                        .accessibilityIdentifier("passwordReset.done")
                        .padding(.top, 22)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        MMField(title: "New password", placeholder: "At least 8 characters", text: $password,
                                isSecure: true, accessibilityID: "passwordReset.password")
                        MMField(title: "Confirm password", placeholder: "Same as above", text: $confirmPassword,
                                isSecure: true, accessibilityID: "passwordReset.confirm")
                    }
                    .padding(.top, 8)

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
            .toolbar {
                if !didReset {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onDone)
                    }
                }
            }
        }
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
