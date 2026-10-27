//
//  SessionManager.swift
//  movemork
//
//  MoveMark — Auth state for the UI. Credentials, persistence and token refresh live in
//  ``NeonAuthClient``; this type decides which screen the user sees.
//

import Foundation
import Observation
import PostgREST

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

@MainActor
@Observable
final class SessionManager {
    enum AuthPhase: Equatable {
        case loading
        /// Plist / build settings missing usable Neon Auth, Data API or MoveMark API URLs (no launch crash).
        case misconfigured
        case signedOut
        case needsOnboarding
        case signedIn
    }

    var authPhase: AuthPhase = .loading
    var userEmail: String = ""
    var firstName: String = ""
    var userId: UUID? = nil

    /// RevenueCat app user id: the Neon Auth id exactly as the server stores it (lowercase), so webhook
    /// events and the API's entitlement rows name the same user.
    var revenueCatAppUserID: String? { userId?.uuidString.lowercased() }

    private var hasResolvedInitialAuthState = false
    /// An email/password sign-in or sign-up is in flight. The phase still reads `.signedOut` during that
    /// window, so a session-expired signal arriving then must not tear down the account being created.
    private var interactiveAuthInFlight = false
    /// User-scoped cache teardown, kicked off at sign-out and awaited before the *next* account
    /// hydrates. Sign-out itself must never wait on disk work, but the previous account's deletion
    /// must never run concurrently with the next account's cache writes either.
    private var pendingSessionCleanup: Task<Void, Never>?

    private let sessionExpiryObserverBox = SessionExpiryObserverBox()

    init() {
        sessionExpiryObserverBox.install { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleSessionExpiredSignal()
            }
        }

        Task {
            await bootstrap()
        }
    }

    deinit {
        sessionExpiryObserverBox.remove()
    }

    func bootstrap() async {
        authPhase = .loading
        hasResolvedInitialAuthState = false

        guard MoveMarkBackendConfig.isConfigured else {
            authPhase = .misconfigured
            hasResolvedInitialAuthState = true
            return
        }

        guard let user = await NeonAuthClient.shared.currentUser() else {
            clearAuthenticatedFields()
            authPhase = .signedOut
            hasResolvedInitialAuthState = true
            return
        }

        do {
            _ = try await NeonAuthClient.shared.validAccessToken()
        } catch NeonAuthError.sessionExpired {
            // The server no longer accepts the stored session (revoked, expired, password reset elsewhere).
            clearAuthenticatedFields()
            authPhase = .signedOut
            hasResolvedInitialAuthState = true
            return
        } catch {
            // Offline or Neon Auth unreachable: the stored session is still ours. Open the app on cached
            // data; requests refresh the token when the network is back.
        }

        await applyAuthenticatedSession(user)
        hasResolvedInitialAuthState = true
    }

    /// `.moveMarkSessionExpired` is a claim, not a fact — reconcile it before acting on it.
    ///
    /// ``NeonAuthClient`` posts it after the server rejected the session (the session is already gone
    /// locally, so this signs out). ``MoveMarkSessionExpiry`` also posts it from error-text heuristics,
    /// which can fire for a transient failure while the session is perfectly valid; asking Neon Auth for a
    /// token settles it. Only a genuinely dead session tears the authenticated UI down.
    private func handleSessionExpiredSignal() async {
        var hasValidCurrentSession = false
        if await NeonAuthClient.shared.currentUser() != nil {
            hasValidCurrentSession = (try? await NeonAuthClient.shared.validAccessToken(forceRefresh: true)) != nil
        }
        if SignedOutReconciliation.shouldDefendAuthenticatedUI(
            authPhase: authPhase,
            hasValidCurrentSession: hasValidCurrentSession,
            interactiveAuthInFlight: interactiveAuthInFlight
        ) {
            return
        }
        guard authPhase != .signedOut else { return }
        await signOut()
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
    private func applyAuthenticatedSession(_ user: NeonAuthUser) async {
        await awaitPreviousSessionCleanup()

        userId = user.id
        userEmail = user.email

        do {
            try await ensureProfileExists(user)

            // Decoded as an array rather than `.single()`: `.single()` throws for "no row", which is
            // indistinguishable from a transport failure. An empty array is a definitive answer.
            let profiles: [ProfileRow] = try await dataAPI
                .from("profiles")
                .select()
                .eq("id", value: user.id)
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
            // while guessing wrong here self-corrects on the next launch.
            authPhase = .signedIn
        }
    }

    /// Ensures a row exists in public.profiles for the session user (required for properties.user_id FK).
    ///
    /// `ignoreDuplicates` makes this idempotent in a single round trip. The previous SELECT-then-INSERT
    /// raced itself: a lost SELECT response led to an INSERT that violated the primary key, and that
    /// throw signed the user out. A merging upsert is not an option here — `ProfileInsert` always
    /// encodes `full_name`, so merging would blank an existing user's name.
    private func ensureProfileExists(_ user: NeonAuthUser) async throws {
        try await dataAPI
            .from("profiles")
            .upsert(
                ProfileInsert(id: user.id, email: user.email, fullName: ""),
                onConflict: "id",
                ignoreDuplicates: true
            )
            .execute()
    }

    /// Whether sign-up actually produced a usable session.
    ///
    /// Neon Auth returns no session when email verification is required for the branch. The two cases
    /// route to completely different places, so the caller is told which one happened rather than left
    /// to assume.
    enum SignUpResult: Equatable {
        case authenticated
        case emailConfirmationRequired
    }

    @discardableResult
    func signUp(email: String, password: String, confirmPassword: String) async throws -> SignUpResult {
        guard MoveMarkBackendConfig.isConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        guard password.count >= 8 else {
            throw AuthError.validation("Password must be at least 8 characters.")
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
            // The response decides this, never an assumption: with verification required there is a
            // user but no session, and walking that user into the authenticated flow would leave every
            // write behind it without a token.
            guard let user = try await NeonAuthClient.shared.signUp(email: trimmedEmail, password: password) else {
                clearAuthenticatedFields()
                authPhase = .signedOut
                hasResolvedInitialAuthState = true
                return .emailConfirmationRequired
            }

            // The profile row and the phase come from the shared path: its upsert is idempotent and
            // `ignoreDuplicates` keeps it from blanking `full_name`. A new row has no onboarding
            // timestamp, so a genuinely new account lands on onboarding.
            await applyAuthenticatedSession(user)
            hasResolvedInitialAuthState = true
            return .authenticated
        } catch {
            clearAuthenticatedFields()
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        guard MoveMarkBackendConfig.isConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        guard !password.isEmpty else {
            throw AuthError.validation("Enter your password.")
        }

        // See signUp: stay `.signedOut` so a failure lands on the form that can display it.
        interactiveAuthInFlight = true
        defer { interactiveAuthInFlight = false }

        let user = try await NeonAuthClient.shared.signIn(email: trimmedEmail, password: password)
        await applyAuthenticatedSession(user)
        hasResolvedInitialAuthState = true
    }

    /// Records onboarding as complete on the profile without changing `authPhase`, so the current
    /// first-run screen (the saved-proof receipt) stays up. Called as soon as the first proof is saved:
    /// if the app is closed on the receipt, the next launch must open the app, not first-run onboarding.
    /// Marks onboarding complete. A name is optional — Account owns identity, so first run no longer asks
    /// for one; without a name only `onboarding_completed_at` is written and any existing `full_name` stays.
    func recordOnboardingCompleted(firstName name: String? = nil) async throws {
        guard MoveMarkBackendConfig.isConfigured, let uid = userId else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try await dataAPI
            .from("profiles")
            .update(
                OnboardingUpdate(
                    fullName: trimmed.isEmpty ? nil : trimmed,
                    onboardingCompletedAt: ISO8601DateFormatter().string(from: Date())
                )
            )
            .eq("id", value: uid)
            .execute()
        if !trimmed.isEmpty { self.firstName = trimmed }
    }

    func completeOnboarding(firstName name: String? = nil) async throws {
        guard MoveMarkBackendConfig.isConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        guard let uid = userId else {
            throw AuthError.validation("Not authenticated.")
        }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        try await dataAPI
            .from("profiles")
            .update(
                OnboardingUpdate(
                    fullName: trimmed.isEmpty ? nil : trimmed,
                    onboardingCompletedAt: ISO8601DateFormatter().string(from: Date())
                )
            )
            .eq("id", value: uid)
            .execute()

        if !trimmed.isEmpty { self.firstName = trimmed }
        authPhase = .signedIn
    }

    /// Updates local name immediately; the profile upsert runs in a fire-and-forget task (not awaited by callers).
    func updateProfileFullName(_ name: String) throws {
        guard MoveMarkBackendConfig.isConfigured else {
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
            await self?.persistProfileFullName(uid: uid, fullName: trimmed, email: emailForSync)
        }
    }

    /// Fire-and-forget profile name sync (upsert). Errors do not propagate to callers.
    private func persistProfileFullName(uid: UUID, fullName: String, email: String?) async {
        guard MoveMarkBackendConfig.isConfigured else { return }
        #if DEBUG
        print("updateProfileFullName remote sync start")
        #endif
        do {
            try await dataAPI
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
        guard MoveMarkBackendConfig.isConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AuthError.validation("Enter your email.")
        }
        try await NeonAuthClient.shared.requestPasswordReset(email: trimmed)
    }

    /// Sets a new password from a reset link's token. Neon Auth revokes the account's sessions, so a
    /// signed-in device is signed out and the user signs in with the new password.
    func completePasswordReset(token: String, newPassword: String, confirmPassword: String) async throws {
        guard MoveMarkBackendConfig.isConfigured else {
            throw AuthError.validation("This build is not configured to reach MoveMark’s servers.")
        }
        guard newPassword.count >= 8 else {
            throw AuthError.validation("Password must be at least 8 characters.")
        }
        guard newPassword == confirmPassword else {
            throw AuthError.validation("Passwords do not match.")
        }
        try await NeonAuthClient.shared.resetPassword(token: token, newPassword: newPassword)
        if authPhase != .signedOut {
            await signOut()
        }
    }

    /// Hard reset: always clear local state even if the server-side sign-out fails (e.g. offline).
    func signOut() async {
        await NeonAuthClient.shared.signOut()

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

/// `fullName` nil is omitted from the update (synthesized `encodeIfPresent`), so an existing name is kept.
private struct OnboardingUpdate: Codable {
    let fullName: String?
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

/// Pure policy for session-expired signals.
///
/// Intentional sign-out sets `authPhase = .signedOut` first; a signal after that must not resurrect a
/// session. An unexpected signal while authenticated UI is still up is defended when Neon Auth can
/// still mint a token for the stored session. An interactive sign-in or sign-up keeps the phase at
/// `.signedOut` while in flight, so it is defended the same way.
enum SignedOutReconciliation {
    static func shouldDefendAuthenticatedUI(
        authPhase: SessionManager.AuthPhase,
        hasValidCurrentSession: Bool,
        interactiveAuthInFlight: Bool = false
    ) -> Bool {
        (authPhase != .signedOut || interactiveAuthInFlight) && hasValidCurrentSession
    }
}
