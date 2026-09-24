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
    /// An email/password sign-in or sign-up is awaiting Supabase. The phase still reads
    /// `.signedOut` during that window, so `.signedOut` reconciliation needs this to tell a
    /// stale provider event apart from a deliberate sign-out.
    private var interactiveAuthInFlight = false
    /// User-scoped cache teardown, kicked off at sign-out and awaited before the *next* account
    /// hydrates. Sign-out itself must never wait on disk work, but the previous account's deletion
    /// must never run concurrently with the next account's cache writes either.
    private var pendingSessionCleanup: Task<Void, Never>?
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

            await applyAuthenticatedSession(session)
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
                    await self.applyAuthenticatedSession(session)

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

        await applyAuthenticatedSession(session)
    }

    private func handleSignedInOrRefreshed(_ session: Session?) async {
        guard let session, isSessionValid(session) else { return }

        await applyAuthenticatedSession(session)
        hasResolvedInitialAuthState = true
    }

    /// A `.signedOut` event is a claim, not a fact — reconcile it before acting on it.
    ///
    /// The auth-state stream races an explicit sign-in: a `.signedOut` queued before the call
    /// can be delivered after `signIn` has already applied its session, and taking it at face
    /// value drops a just-authenticated user back onto Welcome. Asking the client for the
    /// session it currently holds settles it, because that is the same store the stream is
    /// reporting on. Only a genuinely absent or expired session tears the authenticated UI down.
    private func handleSignedOut() async {
        // `authPhase` is the guard against reviving a deliberate sign-out. `signOut()` sets
        // `.signedOut` before Supabase emits its event, so a phase that already reads signed
        // out means this event was asked for and must be obeyed. Only a phase still showing
        // authenticated UI has anything worth defending against a stale event.
        let currentSession = try? await supabase.auth.session
        let hasValidCurrentSession = currentSession.map(isSessionValid) ?? false

        if SignedOutReconciliation.shouldDefendAuthenticatedUI(
            authPhase: authPhase,
            hasValidCurrentSession: hasValidCurrentSession,
            interactiveAuthInFlight: interactiveAuthInFlight
        ), let currentSession {
            await applyAuthenticatedSession(currentSession)
            hasResolvedInitialAuthState = true
            return
        }

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

    /// Identity comes from the already-validated session; the profile read only decides *where* the
    /// user lands. That makes a failed profile read a hydration failure, not an auth failure — hence
    /// non-throwing: it must never sign the user out, and must never tell an onboarded user they
    /// still need onboarding.
    private func applyAuthenticatedSession(_ session: Session) async {
        await awaitPreviousSessionCleanup()

        userId = session.user.id
        userEmail = session.user.email ?? ""

        do {
            try await ensureProfileExists(session: session)

            // Decoded as an array rather than `.single()`: `.single()` throws for "no row", which is
            // indistinguishable from a transport failure. An empty array is a definitive answer.
            let profiles: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id)
                .limit(1)
                .execute()
                .value

            if let profile = profiles.first {
                firstName = profile.fullName ?? ""
                authPhase = profile.onboardingCompletedAt != nil ? .signedIn : .needsOnboarding
            } else {
                // Definitively no profile row — a genuinely new account.
                firstName = ""
                authPhase = .needsOnboarding
            }
        } catch {
            // Indeterminate: the profile could not be read. Stay signed in and let the property layer
            // offer a retry. Preferring `.signedIn` over `.needsOnboarding` is deliberate — onboarding
            // *writes* (it overwrites full_name), so guessing wrong there damages an existing account,
            // while guessing wrong here self-corrects on the next token refresh.
            authPhase = .signedIn
        }
    }

    /// Ensures a row exists in public.profiles for the session user (required for properties.user_id FK).
    ///
    /// `ignoreDuplicates` makes this idempotent in a single round trip. The previous SELECT-then-INSERT
    /// raced itself: a lost SELECT response led to an INSERT that violated the primary key, and that
    /// throw signed the user out. A merging upsert is not an option here — `ProfileInsert` always
    /// encodes `full_name`, so merging would blank an existing user's name.
    private func ensureProfileExists(session: Session) async throws {
        let uid = session.user.id
        let email = session.user.email ?? ""
        try await supabase
            .from("profiles")
            .upsert(
                ProfileInsert(id: uid, email: email, fullName: ""),
                onConflict: "id",
                ignoreDuplicates: true
            )
            .execute()
    }

    /// Whether sign-up actually produced a usable session.
    ///
    /// Supabase returns a user with no session when email confirmation is enabled on the
    /// project. The two cases route to completely different places, so the caller is told
    /// which one happened rather than left to assume.
    enum SignUpResult: Equatable {
        case authenticated
        case emailConfirmationRequired
    }

    @discardableResult
    func signUp(email: String, password: String, confirmPassword: String) async throws -> SignUpResult {
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

        // The phase stays `.signedOut` while the request is in flight: `.loading` swaps the root
        // view, which destroys the auth form along with the error it is about to show. The form
        // owns its own progress state.
        interactiveAuthInFlight = true
        defer { interactiveAuthInFlight = false }

        do {
            let response = try await supabase.auth.signUp(email: trimmedEmail, password: password)

            // The response decides this, never an assumption. With confirmation enabled there
            // is a user but no session, and the old unconditional `.needsOnboarding` walked
            // that user into an authenticated flow they had no token for — every write behind
            // it would have failed.
            guard let session = response.session, isSessionValid(session) else {
                clearAuthenticatedFields()
                authPhase = .signedOut
                hasResolvedInitialAuthState = true
                return .emailConfirmationRequired
            }

            // Both the profile row and the phase come from the shared path: its upsert is
            // idempotent and, unlike the insert this replaces, `ignoreDuplicates` keeps it
            // from blanking `full_name` on an account that already has one. A new row has no
            // onboarding timestamp, so a genuinely new account still lands on onboarding.
            await applyAuthenticatedSession(session)
            hasResolvedInitialAuthState = true
            return .authenticated
        } catch {
            clearAuthenticatedFields()
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

        // See signUp: stay `.signedOut` so a failure lands on the form that can display it.
        interactiveAuthInFlight = true
        defer { interactiveAuthInFlight = false }

        let session = try await supabase.auth.signIn(email: trimmedEmail, password: password)
        await applyAuthenticatedSession(session)
        hasResolvedInitialAuthState = true
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

        // Sign-out is visible immediately; the purge runs behind it. Awaiting here instead would put
        // a lazy ModelContainer init plus a SwiftData delete in front of the user seeing themselves
        // logged out. The race that ordering avoided is closed by awaitPreviousSessionCleanup()
        // before the next account touches the cache, rather than by making logout wait.
        scheduleSessionCleanup()
    }

    /// Chains onto any cleanup already in flight rather than replacing it.
    ///
    /// Replacing the handle would only *look* safe: a second sign-out before the first purge finished
    /// would leave the first task running untracked, and awaiting the second proves nothing about the
    /// first. The next account could then hydrate, write a snapshot, and have the older purge delete
    /// it. Chaining makes awaiting the newest task transitively await every earlier one.
    ///
    /// Nothing is cancelled: the purge does not check `Task.isCancelled`, so cancelling would mislead
    /// without stopping it — and a half-run purge is worse than a duplicated one, which is idempotent.
    private func scheduleSessionCleanup() {
        let previous = pendingSessionCleanup
        pendingSessionCleanup = Task {
            await previous?.value
            await PropertySnapshotCache.shared.removeAll()
            await MoveMarkSignedURLCache.shared.removeAll()
        }
    }

    /// Blocks the incoming account's first cache access until every outgoing purge has finished.
    ///
    /// The handle is deliberately not cleared afterwards — a sign-out landing during this `await`
    /// would install a newer task, and nilling here would drop it. Retaining one finished
    /// `Task<Void, Never>` costs nothing.
    private func awaitPreviousSessionCleanup() async {
        await pendingSessionCleanup?.value
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

/// Pure policy for provider `.signedOut` events.
///
/// Intentional sign-out sets `authPhase = .signedOut` before Supabase emits; that event must not
/// resurrect a session. An unexpected `.signedOut` while authenticated UI is still up may defend
/// against a stale stream event by re-reading a still-valid session. An interactive sign-in or
/// sign-up keeps the phase at `.signedOut` while in flight, so it is defended the same way.
enum SignedOutReconciliation {
    static func shouldDefendAuthenticatedUI(
        authPhase: SessionManager.AuthPhase,
        hasValidCurrentSession: Bool,
        interactiveAuthInFlight: Bool = false
    ) -> Bool {
        (authPhase != .signedOut || interactiveAuthInFlight) && hasValidCurrentSession
    }
}
