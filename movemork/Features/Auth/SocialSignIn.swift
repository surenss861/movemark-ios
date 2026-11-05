//
//  SocialSignIn.swift
//  movemork
//
//  MoveMark — "Continue with Apple / Google" (feature/social-welcome).
//
//  Gated, on purpose:
//  - Release builds compile none of it in (`SocialSignInConfig.isEnabled` is `false`).
//  - Debug builds show it only when launched with a probe auth URL:
//        -MoveMarkSocialProbeAuthURL https://ep-….neonauth.….neon.tech/neondb/auth
//    The URL must be HTTPS on a Neon Auth host, and must not be the app's own auth URL. A probe
//    sign-in uses its own client and Keychain item. It reports only the resulting Neon user id and
//    email (never a token), then signs out of the probe. It never becomes the app's session, so it
//    can't reach dev or production data.
//
//  The app's real session path stays email/password until the probe has proven:
//  - native token acceptance;
//  - no implicit linking to an existing same-email account;
//  - the same user id across iOS and Android.
//

import AuthenticationServices
import CryptoKit
import Foundation
import GoogleSignIn
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

/// What a provider hands back: an OpenID Connect ID token, plus the nonce exactly as it appears in the
/// token's `nonce` claim. Better Auth compares that claim to the request value as-is; Apple signs the
/// SHA-256 we sent, so for Apple this is the hash, not the raw value. Never logged, never persisted.
struct SocialIdentityToken: Sendable {
    let provider: SocialProvider
    let idToken: String
    let nonce: String?
}

enum SocialSignInError: LocalizedError, Equatable {
    /// The person closed the sheet. Not an error to show.
    case cancelled
    /// This provider isn't wired in this build yet (e.g. Google before its SDK is added).
    case providerUnavailable(SocialProvider)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .providerUnavailable(let p):
            return p == .google ? "Google sign-in isn’t set up in this build." : "Apple sign-in isn’t available in this build yet."
        case .failed(let message): return message
        }
    }
}

enum SocialSignInConfig {
    static let probeAuthURLKey = "MoveMarkSocialProbeAuthURL"

    /// Release: always false. Debug: only with a valid probe URL (see the file header).
    static var isEnabled: Bool { probeAuthURL != nil }

    static var probeAuthURL: URL? {
        #if DEBUG
        return validatedProbeURL(UserDefaults.standard.string(forKey: probeAuthURLKey), appAuthURL: MoveMarkBackendConfig.neonAuthURL)
        #else
        return nil
        #endif
    }

    /// Google's iOS and web (server) client ids, only when both are set and the iOS id's reversed form is
    /// registered as a URL scheme (Google redirects back through it). Release clears both in MoveMarkApp.xcconfig.
    static var googleClientIDs: (ios: String, web: String)? {
        let info = Bundle.main.infoDictionary ?? [:]
        let schemes = (info["CFBundleURLTypes"] as? [[String: Any]] ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return validatedGoogleClientIDs(ios: info["MoveMarkGoogleIOSClientID"] as? String,
                                        web: info["MoveMarkGoogleWebClientID"] as? String,
                                        registeredSchemes: schemes)
    }

    static func validatedGoogleClientIDs(ios: String?, web: String?, registeredSchemes: [String]) -> (ios: String, web: String)? {
        let suffix = ".apps.googleusercontent.com"
        guard let ios = ios?.trimmingCharacters(in: .whitespaces), ios.hasSuffix(suffix), ios.count > suffix.count,
              let web = web?.trimmingCharacters(in: .whitespaces), web.hasSuffix(suffix), web.count > suffix.count,
              ios != web
        else { return nil }
        let reversed = "com.googleusercontent.apps." + ios.dropLast(suffix.count)
        guard registeredSchemes.contains(reversed) else { return nil }
        return (ios, web)
    }

    /// HTTPS, a Neon Auth host, and never the app's own auth (dev or production) URL.
    static func validatedProbeURL(_ raw: String?, appAuthURL: URL?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), host.contains(".neonauth."), host.hasSuffix(".neon.tech")
        else { return nil }
        if let app = appAuthURL?.host?.lowercased(), app == host { return nil }
        return url
    }
}

/// Gets an ID token from a provider's native UI.
@MainActor
protocol SocialCredentialProviding {
    func credential(for provider: SocialProvider) async throws -> SocialIdentityToken
}

/// Sign in with Apple (native sheet) and Google Sign-In (GoogleSignIn SDK, system browser sheet).
@MainActor
final class NativeSocialCredentialProvider: NSObject, SocialCredentialProviding {
    private var appleContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var appleController: ASAuthorizationController?

    func credential(for provider: SocialProvider) async throws -> SocialIdentityToken {
        switch provider {
        case .apple: return try await appleCredential()
        case .google: return try await googleCredential()
        }
    }

    /// Google signs the nonce into the ID token exactly as given, so the same string goes to Neon Auth. Only the
    /// ID token is used. Google's own session is cleared straight away, so nothing of Google's stays on the device.
    private func googleCredential() async throws -> SocialIdentityToken {
        guard let ids = SocialSignInConfig.googleClientIDs else { throw SocialSignInError.providerUnavailable(.google) }
        guard let presenter = Self.topViewController() else {
            throw SocialSignInError.failed("Google sign-in couldn’t start. Try again.")
        }
        let nonce = Self.randomNonce()
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: ids.ios, serverClientID: ids.web)
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil, additionalScopes: nil, nonce: nonce)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw SocialSignInError.cancelled
        } catch {
            socialLog.notice("google sign-in failed: \((error as NSError).code, privacy: .public)")
            throw SocialSignInError.failed("Google sign-in didn’t finish. Try again.")
        }
        defer { GIDSignIn.sharedInstance.signOut() }
        guard let token = result.user.idToken?.tokenString, !token.isEmpty else {
            throw SocialSignInError.failed("Google didn’t return a sign-in token. Try again.")
        }
        return SocialIdentityToken(provider: .google, idToken: token, nonce: nonce)
    }

    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private func appleCredential() async throws -> SocialIdentityToken {
        let hashedNonce = Self.sha256Hex(Self.randomNonce())
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleController = controller

        let authorization: ASAuthorization
        do {
            authorization = try await withCheckedThrowingContinuation { continuation in
                appleContinuation = continuation
                controller.performRequests()
            }
        } catch let error as ASAuthorizationError where error.code == .canceled {
            throw SocialSignInError.cancelled
        } catch {
            socialLog.notice("apple authorization failed: \(String(describing: (error as NSError).code), privacy: .public)")
            throw SocialSignInError.failed("Apple sign-in didn’t finish. Try again.")
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8), !token.isEmpty
        else { throw SocialSignInError.failed("Apple didn’t return a sign-in token. Try again.") }
        return SocialIdentityToken(provider: .apple, idToken: token, nonce: hashedNonce)
    }

    // MARK: - Nonce

    nonisolated static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    nonisolated static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension NativeSocialCredentialProvider: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            appleContinuation?.resume(returning: authorization)
            appleContinuation = nil
            appleController = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            appleContinuation?.resume(throwing: error)
            appleContinuation = nil
            appleController = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

/// Probe result shown to QA: identity only, never a token.
struct SocialProbeResult: Equatable, Sendable {
    let provider: SocialProvider
    let userId: UUID
    let email: String
}

/// Runs one social sign-in against the isolated probe project, reports the identity, then signs out of
/// the probe. Never touches `SessionManager` or the app's Keychain session.
@MainActor
final class SocialProbeRunner {
    private let credentials: SocialCredentialProviding
    private let makeClient: (URL) -> NeonAuthClient

    static let probeKeychainService = "\(Bundle.main.bundleIdentifier ?? "movemork").neon-auth.social-probe"

    init(credentials: SocialCredentialProviding? = nil, makeClient: ((URL) -> NeonAuthClient)? = nil) {
        self.credentials = credentials ?? NativeSocialCredentialProvider()
        self.makeClient = makeClient ?? { NeonAuthClient(baseURL: $0, keychainService: SocialProbeRunner.probeKeychainService) }
    }

    func run(_ provider: SocialProvider, probeURL: URL) async throws -> SocialProbeResult {
        let token = try await credentials.credential(for: provider)
        let client = makeClient(probeURL)
        do {
            let user = try await client.signInSocial(token)
            await client.signOut()
            socialLog.notice("probe sign-in ok provider=\(provider.rawValue, privacy: .public)")
            return SocialProbeResult(provider: provider, userId: user.id, email: user.email)
        } catch {
            await client.endSessionLocally(notify: false)
            throw error
        }
    }
}
