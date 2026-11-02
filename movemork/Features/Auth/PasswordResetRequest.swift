//
//  PasswordResetRequest.swift
//  movemork
//
//  The rules behind "Forgot password?": when it appears, what counts as a usable email, how a send answers
//  (always the same, whether or not the address has an account), how long before another send, and which
//  failures mean the link itself is dead. Kept apart from the view so they are unit-tested.
//

import Foundation

enum PasswordResetRequest {
    /// "Forgot password?" appears only when reset emails link to a page this build trusts and opens. Without
    /// one, Neon Auth's default link would land on a page that can't hand the token to the app.
    static func isAvailable(resetPage: URL? = MoveMarkBackendConfig.passwordResetURL) -> Bool {
        resetPage != nil
    }

    /// Seconds before another link can be sent from the same screen. Neon Auth also throttles server-side.
    static let resendCooldown = 60

    static let expiredLinkMessage = "This reset link is invalid or has expired. Request a new one."

    enum Outcome: Equatable {
        /// Show the neutral "check your email" state.
        case sent
        /// Stay on the form with this message.
        case failed(String)
    }

    /// Every send takes at least this long on screen, so how fast the server answered can't hint at
    /// whether the address has an account (Neon Auth also evens out its own timing).
    static let minimumSendDuration: Duration = .milliseconds(1200)

    /// Runs one send and returns its error (nil when sent), never sooner than `minimum`.
    static func send(minimum: Duration = minimumSendDuration,
                     _ operation: () async throws -> Void) async -> Error? {
        let started = ContinuousClock.now
        var failure: Error?
        do { try await operation() } catch { failure = error }
        let remaining = minimum - (ContinuousClock.now - started)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
        return failure
    }

    /// A message when the address can't be sent to as typed, or nil when it can.
    static func validationMessage(forEmail email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter your email." }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."), !trimmed.contains(" ")
        else { return "Enter a valid email." }
        return nil
    }

    /// How a finished send is shown. An answer that would say the account doesn't exist is shown as sent:
    /// the screen must never tell anyone which addresses have a MoveMark account.
    static func outcome(for error: Error?) -> Outcome {
        guard let error else { return .sent }
        if error is URLError { return .failed("No connection. Check your internet and try again.") }
        if let auth = error as? NeonAuthError {
            switch auth {
            case .rejected(let code, _):
                switch code {
                case "USER_NOT_FOUND", "USER_EMAIL_NOT_FOUND", "EMAIL_NOT_FOUND":
                    return .sent
                case "RATE_LIMITED", "INVALID_EMAIL":
                    return .failed(auth.errorDescription ?? genericFailure)
                default:
                    return .failed(genericFailure)
                }
            case .notConfigured:
                return .failed(auth.errorDescription ?? genericFailure)
            case .sessionExpired, .invalidResponse:
                return .failed(genericFailure)
            }
        }
        if let validation = error as? SessionManager.AuthError, let message = validation.errorDescription {
            return .failed(message)
        }
        return .failed(genericFailure)
    }

    /// The reset link's token was refused (expired, already used, malformed): a new link is the only way on.
    static func isRejectedToken(_ error: Error) -> Bool {
        guard case .rejected(let code, _) = error as? NeonAuthError else { return false }
        return code == "INVALID_TOKEN" || code == "TOKEN_EXPIRED"
    }

    static let genericFailure = "Couldn’t send the reset link. Try again."
}

#if DEBUG
/// UI tests only (`-MMPasswordResetFixture` launch argument): a reset page is configured so "Forgot
/// password?" shows, and the two reset calls answer locally — no request leaves the device, no email is
/// sent. The token `expired` is refused like an expired link. Compiled out of release builds.
enum PasswordResetFixture {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-MMPasswordResetFixture")
    static let resetPage = URL(string: "https://account.movemark.ca/reset")!
    static let expiredToken = "expired"
}
#endif
