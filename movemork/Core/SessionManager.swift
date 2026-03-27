//
//  SessionManager.swift
//  movemork
//
//  MoveMark — Auth state and session persistence.
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class SessionManager {
    enum AuthPhase: Equatable {
        case loading
        case signedOut
        case needsOnboarding
        case signedIn
    }

    var authPhase: AuthPhase = .loading
    var userEmail: String = ""
    var firstName: String = ""
    var userId: UUID? = nil

    private var hasResolvedInitialAuthState = false
    private var hasStartedAuthListener = false
    /// Owned by `SessionManager` on the main actor only; `nonisolated(unsafe)` so `deinit` can cancel without actor violations.
    nonisolated(unsafe) private var authStateTask: Task<Void, Never>? = nil

    init() {
        Task {
            await bootstrap()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func bootstrap() async {
        authPhase = .loading
        hasResolvedInitialAuthState = false

        startAuthListenerIfNeeded()

        do {
            let session = try await supabase.auth.session

            guard isSessionValid(session) else {
                clearAuthenticatedFields()
                authPhase = .signedOut
                hasResolvedInitialAuthState = true
                return
            }

            try await applyAuthenticatedSession(session)
            hasResolvedInitialAuthState = true
        } catch {
            clearAuthenticatedFields()
            authPhase = .signedOut
            hasResolvedInitialAuthState = true
        }
    }

    private func startAuthListenerIfNeeded() {
        guard !hasStartedAuthListener else { return }
        hasStartedAuthListener = true

        authStateTask = Task { [weak self] in
            guard let self else { return }

            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { return }

                switch event {
                case .initialSession:
                    await self.handleInitialSession(session)

                case .signedIn, .tokenRefreshed:
                    await self.handleSignedInOrRefreshed(session)

                case .signedOut:
                    await self.handleSignedOut()

                case .userUpdated:
                    guard let session, self.isSessionValid(session) else { continue }
                    do {
                        try await self.applyAuthenticatedSession(session)
                    } catch {
                        self.clearAuthenticatedFields()
                        self.authPhase = .signedOut
                    }

                default:
                    break
                }
            }
        }
    }

    private func handleInitialSession(_ session: Session?) async {
        guard !hasResolvedInitialAuthState else { return }
        hasResolvedInitialAuthState = true

        guard let session, isSessionValid(session) else {
            clearAuthenticatedFields()
            authPhase = .signedOut
            return
        }

        do {
            try await applyAuthenticatedSession(session)
        } catch {
            clearAuthenticatedFields()
            authPhase = .signedOut
        }
    }

    private func handleSignedInOrRefreshed(_ session: Session?) async {
        guard let session, isSessionValid(session) else { return }

        do {
            try await applyAuthenticatedSession(session)
            hasResolvedInitialAuthState = true
        } catch {
            clearAuthenticatedFields()
            authPhase = .signedOut
            hasResolvedInitialAuthState = true
        }
    }

    private func handleSignedOut() async {
        clearAuthenticatedFields()
        authPhase = .signedOut
        hasResolvedInitialAuthState = true
    }

    /// Do not blindly trust the first emitted session when using emitLocalSessionAsInitialSession.
    private func isSessionValid(_ session: Session) -> Bool {
        let expiry = session.expiresAt
        return Date(timeIntervalSince1970: TimeInterval(expiry)) > Date()
    }

    private func clearAuthenticatedFields() {
        userId = nil
        userEmail = ""
        firstName = ""
    }

    private func applyAuthenticatedSession(_ session: Session) async throws {
        userId = session.user.id
        userEmail = session.user.email ?? ""

        try await ensureProfileExists(session: session)

        let profile: ProfileRow? = try? await supabase
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value

        if let profile {
            firstName = profile.fullName ?? ""
            authPhase = profile.onboardingCompletedAt != nil ? .signedIn : .needsOnboarding
        } else {
            firstName = ""
            authPhase = .needsOnboarding
        }
    }

    /// Ensures a row exists in public.profiles for the session user (required for properties.user_id FK).
    /// Inserts only when missing. Throws if profile is missing and insert fails (caller must not allow property creation).
    private func ensureProfileExists(session: Session) async throws {
        let uid = session.user.id
        let email = session.user.email ?? ""
        let exists: ProfileRow? = try? await supabase
            .from("profiles")
            .select()
            .eq("id", value: uid)
            .single()
            .execute()
            .value
        guard exists == nil else { return }
        try await supabase
            .from("profiles")
            .insert(ProfileInsert(id: uid, email: email, fullName: ""))
            .execute()
    }

    func signUp(email: String, password: String, confirmPassword: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        guard password.count >= 6 else {
            throw AuthError.validation("Password must be at least 6 characters.")
        }
        guard password == confirmPassword else {
            throw AuthError.validation("Passwords do not match.")
        }

        authPhase = .loading

        do {
            let response = try await supabase.auth.signUp(email: trimmedEmail, password: password)
            let uid = response.user.id
            userId = uid
            userEmail = trimmedEmail

            try await supabase
                .from("profiles")
                .upsert(ProfileInsert(id: uid, email: trimmedEmail, fullName: ""))
                .execute()

            firstName = ""
            authPhase = .needsOnboarding
            hasResolvedInitialAuthState = true
        } catch {
            authPhase = .signedOut
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        guard password.count >= 6 else {
            throw AuthError.validation("Enter a valid password.")
        }

        authPhase = .loading

        do {
            let session = try await supabase.auth.signIn(email: trimmedEmail, password: password)
            try await applyAuthenticatedSession(session)
            hasResolvedInitialAuthState = true
        } catch {
            authPhase = .signedOut
            throw error
        }
    }

    /// OAuth sign-in (Apple) through Supabase + ASWebAuthenticationSession.
    func signInWithApple() async throws {
        authPhase = .loading
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: supabaseOAuthRedirectURL
            )
            hasResolvedInitialAuthState = true
        } catch {
            authPhase = .signedOut
            throw error
        }
    }

    /// OAuth sign-in (Google) through Supabase + ASWebAuthenticationSession.
    func signInWithGoogle() async throws {
        authPhase = .loading
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: supabaseOAuthRedirectURL
            )
            hasResolvedInitialAuthState = true
        } catch {
            authPhase = .signedOut
            throw error
        }
    }

    func completeOnboarding(firstName name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your name.")
        }
        guard let uid = userId else {
            throw AuthError.validation("Not authenticated.")
        }

        try await supabase
            .from("profiles")
            .update(
                OnboardingUpdate(
                    fullName: trimmed,
                    onboardingCompletedAt: ISO8601DateFormatter().string(from: Date())
                )
            )
            .eq("id", value: uid)
            .execute()

        self.firstName = trimmed
        authPhase = .signedIn
    }

    /// Updates the profile full name in DB and local state.
    func updateProfileFullName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your full name.")
        }
        guard let uid = userId else {
            throw AuthError.validation("Not authenticated.")
        }
        try await supabase
            .from("profiles")
            .update(ProfileFullNameUpdate(fullName: trimmed))
            .eq("id", value: uid)
            .execute()
        firstName = trimmed
    }

    /// Sends a password reset email to the given address (e.g. current user's email).
    func sendPasswordReset(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        try await supabase.auth.resetPasswordForEmail(trimmed)
    }

    /// Hard reset: always clear local state even if Supabase signOut fails (e.g. offline).
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            // Intentionally swallow. We still clear local state below.
        }

        clearAuthenticatedFields()
        authPhase = .signedOut
        hasResolvedInitialAuthState = true
    }

    enum AuthError: LocalizedError {
        case validation(String)

        var errorDescription: String? {
            switch self {
            case .validation(let msg): return msg
            }
        }
    }
}

// MARK: - Profile DTOs

private struct ProfileRow: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let onboardingCompletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

private struct ProfileInsert: Codable {
    let id: UUID
    let email: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
    }
}

private struct OnboardingUpdate: Codable {
    let fullName: String
    let onboardingCompletedAt: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

private struct ProfileFullNameUpdate: Codable {
    let fullName: String
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}
