//
//  PasswordResetView.swift
//  movemork
//
//  Set a new password from a reset link: the HTTPS Universal Link (`https://account.movemark.ca/reset?token=…`)
//  or the `movemark://reset-password?token=…` scheme (the reset page's "Open MoveMark" button). Neon Auth
//  sends a bad or expired link to the page as `?error=INVALID_TOKEN`; the page forwards that, and this
//  screen opens straight on "Link expired" with the way to ask for a new one.
//

import SwiftUI

enum PasswordResetLink {
    /// What a reset link carries into the app.
    enum Payload: Identifiable, Equatable {
        /// Set a new password with this token.
        case token(String)
        /// Neon Auth already judged the link invalid or expired (`error=…` instead of `token=…`).
        case invalid

        var id: String {
            switch self {
            case .token(let value): "token:\(value)"
            case .invalid: "invalid"
            }
        }
    }

    /// The payload of a reset link (the configured HTTPS reset page, or `movemark://reset-password`), or nil
    /// for any other URL. Parameters are read from the query, then from the fragment (`#token=…`).
    static func payload(from url: URL, resetPage: URL? = MoveMarkBackendConfig.passwordResetURL) -> Payload? {
        let isScheme = url.scheme?.lowercased() == "movemark" && url.host?.lowercased() == "reset-password"
        let isPage = resetPage.map {
            url.scheme?.lowercased() == "https" && url.host?.lowercased() == $0.host?.lowercased() && url.path == $0.path
        } ?? false
        guard isScheme || isPage else { return nil }

        let items = parameters(of: url)
        if let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty {
            return .token(token)
        }
        if let error = items.first(where: { $0.name == "error" })?.value, !error.isEmpty {
            return .invalid
        }
        return nil
    }

    /// The token from a reset link, or nil for any other URL (or a link that carries only an error).
    static func token(from url: URL, resetPage: URL? = MoveMarkBackendConfig.passwordResetURL) -> String? {
        if case .token(let value) = payload(from: url, resetPage: resetPage) { return value }
        return nil
    }

    private static func parameters(of url: URL) -> [URLQueryItem] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [] }
        var items = components.queryItems ?? []
        if let fragment = components.fragment, !fragment.isEmpty {
            var fragmentQuery = URLComponents()
            fragmentQuery.percentEncodedQuery = fragment
            items += fragmentQuery.queryItems ?? []
        }
        return items
    }
}

extension Notification.Name {
    /// Opens the sign-in surface over Welcome in the mode carried as `object` (`AuthContainerView.Mode`):
    /// a finished reset goes on to sign in, an expired link to "Reset your password".
    static let moveMarkOpenAuth = Notification.Name("moveMarkOpenAuth")
}

struct PasswordResetView: View {
    @Environment(SessionManager.self) private var sessionManager

    let token: String?
    /// Closes the sheet; a mode asks Welcome to open the auth surface in it afterwards.
    let onDone: (AuthContainerView.Mode?) -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var didReset = false
    /// Neon Auth rejected the token (expired, used, or malformed): saving again can't work.
    @State private var tokenRejected = false
    private enum Field: Hashable { case password, confirm }
    @FocusState private var focusedField: Field?

    init(link: PasswordResetLink.Payload, onDone: @escaping (AuthContainerView.Mode?) -> Void) {
        switch link {
        case .token(let value):
            self.token = value
            _tokenRejected = State(initialValue: false)
        case .invalid:
            self.token = nil
            _tokenRejected = State(initialValue: true)
        }
        self.onDone = onDone
    }

    /// Snapshot tests only: open on the done, failed or expired state. Production uses the init above.
    init(token: String, previewDidReset: Bool, previewError: String = "", previewTokenRejected: Bool = false,
         onDone: @escaping (AuthContainerView.Mode?) -> Void = { _ in }) {
        self.token = token
        self.onDone = onDone
        _didReset = State(initialValue: previewDidReset)
        _errorMessage = State(initialValue: previewError)
        _tokenRejected = State(initialValue: previewTokenRejected)
    }

    private var title: String {
        if didReset { return "Password updated" }
        if tokenRejected { return "Link expired" }
        return "Choose a new password"
    }

    private var subtitle: String {
        if didReset { return "Sign in with your new password." }
        if tokenRejected { return "Reset links work once and expire soon after they’re sent." }
        return "Use at least 8 characters."
    }

    /// Entry's dark header (wordmark, title, close) over the light sheet — the same surface as sign in, so a
    /// reset link lands inside MoveMark rather than in a generic form. Reachable only from the link itself.
    var body: some View {
        MMScreen(title: title, subtitle: subtitle) {
            if !didReset {
                Button { onDone(nil) } label: {
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
                // The reset signs this device out (SessionManager), so the next step is always signing in.
                MMPrimaryButton(title: "Sign in") { onDone(.signIn) }
                    .accessibilityIdentifier("passwordReset.done")
            } else if tokenRejected {
                expiredContent
            } else {
                newPasswordForm
            }
        }
        .presentationBackground(MMInk.sheet)
        .interactiveDismissDisabled(isSaving)
    }

    private var newPasswordForm: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    /// A signed-out person goes straight to asking for a new link; a signed-in one just closes (they can
    /// still change it after signing out, and nothing here should sign them out).
    private var expiredContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMNotice(message: PasswordResetRequest.expiredLinkMessage)
                .accessibilityIdentifier("passwordReset.expired")
            if sessionManager.authPhase != .signedIn && sessionManager.authPhase != .needsOnboarding {
                MMPrimaryButton(title: "Request a new link") { onDone(.resetPassword) }
                    .accessibilityIdentifier("passwordReset.requestNew")
                    .padding(.top, 22)
            } else {
                MMPrimaryButton(title: "Done") { onDone(nil) }
                    .accessibilityIdentifier("passwordReset.close")
                    .padding(.top, 22)
            }
        }
    }

    private func save() {
        guard !isSaving, let token else { return }
        focusedField = nil
        isSaving = true
        errorMessage = ""
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await sessionManager.completePasswordReset(token: token, newPassword: password, confirmPassword: confirmPassword)
                didReset = true
            } catch where PasswordResetRequest.isRejectedToken(error) {
                tokenRejected = true
            } catch {
                errorMessage = MoveMarkFlowMessage.authOperationFailed(error)
            }
        }
    }
}
