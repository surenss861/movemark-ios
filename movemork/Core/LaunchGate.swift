//
//  LaunchGate.swift
//  movemork
//
//  @file Where a signed-in renter lands at launch, decided in one place from what the server definitively said.
//        The rule: UNKNOWN is not INCOMPLETE. A lookup that failed (offline, timeout, server error) never sends
//        a renter into onboarding or first-run proof; only a definitive answer ("no profile", "not onboarded and
//        no rental", "a rental with no documented room") does. Unknown lands on the app with its recoverable
//        load-failure state, which keeps a retry and never implies the proof is gone.
//  @domain launch
//

import Foundation

enum LaunchGate {
    /// The profile read: what it said about onboarding, or that it couldn't be read.
    enum Profile: Equatable {
        case onboarded
        case notOnboarded
        /// Definitively no row (a genuinely new account).
        case missing
        /// The read failed.
        case unknown
    }

    /// Whether the account has a rental, or that it couldn't be checked.
    enum Rentals: Equatable {
        case some
        case none
        case unknown
    }

    /// The session-level phase after auth and the profile read (before the legal step, which wraps it).
    /// - A profile that says "not onboarded" is believed only together with a definitive "no rental": an account
    ///   with a rental finished first run even if recording that failed (e.g. offline on the receipt).
    /// - Anything unknown opens the app, whose property layer shows a retry when it can't load.
    static func sessionPhase(profile: Profile, rentals: Rentals) -> SessionManager.AuthPhase {
        switch (profile, rentals) {
        case (.onboarded, _), (.unknown, _):
            return .signedIn
        case (.notOnboarded, .none), (.missing, .none):
            return .needsOnboarding
        case (.notOnboarded, .some), (.missing, .some), (.notOnboarded, .unknown), (.missing, .unknown):
            return .signedIn
        }
    }

    /// True when the profile should be marked onboarded because the account evidently is (it has a rental).
    static func shouldBackfillOnboarding(profile: Profile, rentals: Rentals) -> Bool {
        profile == .notOnboarded && rentals == .some
    }

    /// Where the signed-in root goes once properties are being loaded.
    enum Destination: Equatable {
        case wait
        case loadFailure
        case firstRun
        case app
    }

    struct SignedInState: Equatable {
        var hasCompletedInitialFetch: Bool
        /// The last property load ended in an error rather than an answer.
        var lastFetchFailed: Bool
        /// A property is on screen (from this load or the local snapshot cache).
        var hasCurrentProperty: Bool
        /// Only meaningful after a successful load.
        var propertiesEmpty: Bool
        /// Move-in rooms with photos on the current property; nil when there is no current property.
        var documentedRoomCount: Int?
        /// Device-local "first proof done" flag.
        var firstRunComplete: Bool
        /// The first-run receipt is on screen and must stay until dismissed.
        var awaitingReceiptDismissal: Bool
    }

    static func signedInDestination(_ s: SignedInState) -> Destination {
        guard s.hasCompletedInitialFetch else { return .wait }
        // Nothing to show and the load failed: the retry, never an empty account.
        if s.lastFetchFailed && !s.hasCurrentProperty { return .loadFailure }
        if s.firstRunComplete { return .app }
        if s.awaitingReceiptDismissal { return .firstRun }
        // Unknown with a cached rental: open the app on it, never first run.
        if s.lastFetchFailed { return .app }
        // A successful load: these answers are definitive.
        if s.propertiesEmpty { return .firstRun }
        guard let documented = s.documentedRoomCount else { return .firstRun }
        return documented == 0 ? .firstRun : .app
    }
}
