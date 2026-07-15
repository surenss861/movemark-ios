//
//  SessionManager.swift
//  movemork
//
//  MoveMark — Auth state and session persistence.
//

import Foundation
import Observation
import Supabase

/// Holds the session-expiry notification observer so `deinit` can remove it off the main actor.
private final class SessionExpiryObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var token: NSObjectProtocol?

    nonisolated init() {}

    nonisolated func install(handler: @escaping () -> Void) {
        lock.lock()
        if let token { NotificationCenter.default.removeObserver(token) }
        token = NotificationCenter.default.addObserver(
            forName: .moveMarkSessionExpired,
            object: nil,
            queue: .main,
            using: { _ in handler() }
        )
        lock.unlock()
    }

    nonisolated func remove() {
        lock.lock()
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
        lock.unlock()
    }
}

/// Thread-safe holder so `SessionManager.deinit` can cancel the auth listener without touching `@MainActor` state.
private final class TaskCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    /// Guarded by `lock`; `nonisolated(unsafe)` so this helper type is not forced onto the main actor.
    nonisolated(unsafe) private var task: Task<Void, Never>?

    nonisolated init() {}

    nonisolated func store(_ newTask: Task<Void, Never>?) {
        lock.lock()
        let previous = task
        task = newTask
        lock.unlock()
        previous?.cancel()
    }

    nonisolated func cancel() {
        lock.lock()
        let current = task
        task = nil
        lock.unlock()
        current?.cancel()
    }
}

@MainActor
@Observable
final class SessionManager {
    enum AuthPhase: Equatable {
        case loading
        /// Plist / build settings missing usable Supabase URL and anon key (no launch crash).
        case misconfigured
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
    /// `SessionManager` is `@MainActor`; `deinit` is not — the box is the only cross-isolation handle to the listener task.
    private let authStateTaskBox = TaskCancellationBox()

    private let sessionExpiryObserverBox = SessionExpiryObserverBox()

    init() {
        sessionExpiryObserverBox.install { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.signOut()
            }
        }

        Task {
            await bootstrap()
        }
    }

    deinit {
        authStateTaskBox.cancel()
        sessionExpiryObserverBox.remove()
    }

    func bootstrap() async {
        authPhase = .loading
        hasResolvedInitialAuthState = false

        guard isSupabaseConfigured else {
            authPhase = .misconfigured
            hasResolvedInitialAuthState = true
            return
        }

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
        guard isSupabaseConfigured else { return }
        guard !hasStartedAuthListener else { return }
        hasStartedAuthListener = true

        authStateTaskBox.store(Task { [weak self] in
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
        })
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
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
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
            MoveMarkMetaAppEvents.logCompleteRegistration()
        } catch {
            authPhase = .signedOut
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
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
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
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
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
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
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
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
        MoveMarkMetaAppEvents.logCompleteTutorial()
    }

    /// Updates local name immediately; Supabase upsert runs in a fire-and-forget task (not awaited by callers).
    func updateProfileFullName(_ name: String) throws {
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your full name.")
        }
        guard let uid = userId else {
            throw AuthError.validation("Not authenticated.")
        }

        let emailForSync: String? = userEmail.isEmpty ? nil : userEmail

        firstName = trimmed

        Task { @MainActor [weak self] in
            await self?.persistProfileFullNameToSupabase(uid: uid, fullName: trimmed, email: emailForSync)
        }
    }

    /// Fire-and-forget profile name sync (upsert). Errors do not propagate to callers.
    private func persistProfileFullNameToSupabase(uid: UUID, fullName: String, email: String?) async {
        guard isSupabaseConfigured else { return }
        #if DEBUG
        print("updateProfileFullName remote sync start")
        #endif
        do {
            try await supabase
                .from("profiles")
                .upsert(ProfileUpsert(id: uid, email: email, fullName: fullName))
                .execute()
            #if DEBUG
            print("updateProfileFullName remote sync OK")
            #endif
        } catch {
            #if DEBUG
            print("updateProfileFullName remote sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Sends a password reset email to the given address (e.g. current user's email).
    func sendPasswordReset(email: String) async throws {
        guard isSupabaseConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        try await supabase.auth.resetPasswordForEmail(trimmed)
    }

    /// Hard reset: always clear local state even if Supabase signOut fails (e.g. offline).
    func signOut() async {
        if isSupabaseConfigured {
            do {
                try await supabase.auth.signOut()
            } catch {
                // Intentionally swallow. We still clear local state below.
            }
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

private struct ProfileUpsert: Encodable {
    let id: UUID
    let email: String?
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        if let email, !email.isEmpty {
            try container.encode(email, forKey: .email)
        }
    }
}
