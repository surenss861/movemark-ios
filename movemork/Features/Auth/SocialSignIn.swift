//
//  SocialSignIn.swift
//  movemork
//
//  MoveMark — "Continue with Apple / Google", through Neon Auth's supported browser flow.
//
//  Managed Neon Auth ignores native ID tokens: `/sign-in/social` always answers with a browser URL. So:
//    1. The app posts the provider and a callback, and keeps the session-challenge cookie for this attempt.
//    2. A system browser sheet (ASWebAuthenticationSession) runs the Google/Apple sign-in.
//    3. Neon returns to https://account.movemark.ca/auth/return with a single-use verifier; that page hands it to
//       movemark://auth/callback, which only the sheet that started the attempt receives.
//    4. The app exchanges verifier + challenge cookie at `/get-session` for the real session.
//  The browser and the app don't share cookies, and don't need to: the challenge stays in the app, in memory, for
//  one attempt. A verifier without it is refused by Neon (SESSION_CHALLENGE_COOKIE_NOT_FOUND).
//
//  Gated: Release is always `.off`. Debug needs `-MoveMarkSocialLive YES`. No customer build shows the buttons until
//  sign-in and the account-linking tests have passed.
//

import AuthenticationServices
import Foundation
import os
import UIKit

private let socialLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "movemork", category: "SocialSignIn")

enum SocialProvider: String, CaseIterable, Sendable {
    case apple
    case google

    var buttonTitle: String {
        switch self {
        case .apple: return "Continue with Apple"
        case .google: return "Continue with Google"
        }
    }

    /// Platform order: Apple first on iOS (Google first on Android).
    static let iOSOrder: [SocialProvider] = [.apple, .google]
}

enum SocialSignInError: LocalizedError, Equatable {
    /// The person closed the sheet. Not an error to show.
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .failed(let message): return message
        }
    }
}

/// How the Welcome buttons behave in this build.
enum SocialSignInMode: Equatable {
    /// Hidden. Always, in Release.
    case off
    /// Signs in for real, through the app's own Neon Auth (Debug test builds only).
    case live
}

enum SocialSignInConfig {
    static let liveKey = "MoveMarkSocialLive"

    static var mode: SocialSignInMode {
        #if DEBUG
        return resolvedMode(liveFlag: UserDefaults.standard.bool(forKey: liveKey))
        #else
        return .off
        #endif
    }

    static func resolvedMode(liveFlag: Bool) -> SocialSignInMode { liveFlag ? .live : .off }

    static var isEnabled: Bool { mode != .off }
}

/// Where Neon sends the browser, and how the result comes back to the app.
enum SocialBrowserReturn {
    /// Must be a Neon Auth trusted domain; custom schemes are refused as a callback.
    static let callbackURL = URL(string: "https://account.movemark.ca/auth/return")!
    static let appScheme = "movemark"
    static let verifierParameter = "neon_auth_session_verifier"

    /// The verifier from `movemark://auth/callback?…`. Anything else is a failed sign-in, never a session.
    static func verifier(from url: URL) throws -> String {
        guard url.scheme == appScheme, url.host == "auth", url.path == "/callback",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { throw SocialSignInError.failed("Sign-in didn’t finish. Try again.") }
        if let verifier = items.first(where: { $0.name == verifierParameter })?.value, !verifier.isEmpty {
            return verifier
        }
        #if DEBUG
        // Sign-in QA: Neon's short error code only. The return page limits it to a plain code, never a token.
        print("[social-qa] browser-return error=\(items.first(where: { $0.name == "error" })?.value ?? "none")")
        #endif
        if items.first(where: { $0.name == "error" })?.value == "access_denied" { throw SocialSignInError.cancelled }
        throw SocialSignInError.failed("Sign-in didn’t finish. Try again.")
    }
}

/// Opens the sign-in URL and returns the URL the flow came back to.
@MainActor
protocol SocialBrowserPresenting {
    func open(_ url: URL) async throws -> URL
}

/// ASWebAuthenticationSession: the system's secure sheet. Only this session receives its callback, so another app
/// can't intercept the result. Ephemeral: nothing from Safari carries in, and nothing stays behind.
@MainActor
final class SystemBrowserPresenter: NSObject, SocialBrowserPresenting, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func open(_ url: URL) async throws -> URL {
        defer { session = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(SocialBrowserReturn.appScheme)
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: SocialSignInError.cancelled)
                } else {
                    socialLog.notice("browser sign-in failed: \((error as NSError?)?.code ?? 0, privacy: .public)")
                    #if DEBUG
                    print("[social-qa] browser-sheet error=\((error as NSError?)?.code ?? 0)")
                    #endif
                    continuation.resume(throwing: SocialSignInError.failed("Sign-in didn’t finish. Try again."))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                continuation.resume(throwing: SocialSignInError.failed("Sign-in couldn’t start. Try again."))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
