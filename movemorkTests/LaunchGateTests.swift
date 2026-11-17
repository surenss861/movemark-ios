//
//  LaunchGateTests.swift
//  movemorkTests
//
//  @file The launch rule: UNKNOWN is not INCOMPLETE. A failed lookup never routes a renter into onboarding or
//        first-run proof; only definitive answers do, and genuine first-run requirements are never skipped.
//  @domain launch
//

import Testing
@testable import MoveMark

@MainActor
struct LaunchGateTests {
    // MARK: Session phase (profile + rentals)

    @Test func onboardedProfileOpensTheApp() {
        for rentals in [LaunchGate.Rentals.some, .none, .unknown] {
            #expect(LaunchGate.sessionPhase(profile: .onboarded, rentals: rentals) == .signedIn)
        }
    }

    @Test func unreadableProfileNeverMeansOnboarding() {
        for rentals in [LaunchGate.Rentals.some, .none, .unknown] {
            #expect(LaunchGate.sessionPhase(profile: .unknown, rentals: rentals) == .signedIn)
        }
    }

    @Test func notOnboardedWithNoRentalIsGenuineFirstRun() {
        #expect(LaunchGate.sessionPhase(profile: .notOnboarded, rentals: .none) == .needsOnboarding)
        #expect(LaunchGate.sessionPhase(profile: .missing, rentals: .none) == .needsOnboarding)
    }

    /// The onboarding write was lost (offline on the first receipt): the rental proves first run happened.
    @Test func notOnboardedWithARentalOpensTheAppAndBackfills() {
        #expect(LaunchGate.sessionPhase(profile: .notOnboarded, rentals: .some) == .signedIn)
        #expect(LaunchGate.shouldBackfillOnboarding(profile: .notOnboarded, rentals: .some))
    }

    /// Offline rental check: unknown, so the app (with its retry), not onboarding.
    @Test func notOnboardedWithUnknownRentalsIsNotOnboarding() {
        #expect(LaunchGate.sessionPhase(profile: .notOnboarded, rentals: .unknown) == .signedIn)
        #expect(LaunchGate.sessionPhase(profile: .missing, rentals: .unknown) == .signedIn)
        #expect(!LaunchGate.shouldBackfillOnboarding(profile: .notOnboarded, rentals: .unknown))
        #expect(!LaunchGate.shouldBackfillOnboarding(profile: .notOnboarded, rentals: .none))
    }

    // MARK: Signed-in destination (properties + first room)

    private func state(fetched: Bool = true, failed: Bool = false, current: Bool = true, empty: Bool = false,
                       documented: Int? = 2, complete: Bool = false, receipt: Bool = false) -> LaunchGate.SignedInState {
        .init(hasCompletedInitialFetch: fetched, lastFetchFailed: failed, hasCurrentProperty: current,
              propertiesEmpty: empty, documentedRoomCount: documented, firstRunComplete: complete,
              awaitingReceiptDismissal: receipt)
    }

    @Test func waitsForTheFirstLoad() {
        #expect(LaunchGate.signedInDestination(state(fetched: false)) == .wait)
    }

    /// Offline with nothing cached: the recoverable retry, never an empty account / first run.
    @Test func failedLoadWithNothingCachedShowsTheRetry() {
        #expect(LaunchGate.signedInDestination(state(failed: true, current: false, empty: true, documented: nil)) == .loadFailure)
    }

    /// Offline with a cached rental that has no documented room yet (or a fresh device flag): still the app.
    @Test func failedLoadWithACachedRentalOpensTheAppNotFirstRun() {
        #expect(LaunchGate.signedInDestination(state(failed: true, current: true, empty: true, documented: 0)) == .app)
        #expect(LaunchGate.signedInDestination(state(failed: true, current: true, empty: true, documented: 3)) == .app)
    }

    @Test func definitiveNoRentalIsFirstRun() {
        #expect(LaunchGate.signedInDestination(state(current: false, empty: true, documented: nil)) == .firstRun)
    }

    /// A rental with no documented room after a successful load: first proof is a genuine requirement.
    @Test func definitiveNoDocumentedRoomIsFirstRun() {
        #expect(LaunchGate.signedInDestination(state(documented: 0)) == .firstRun)
    }

    @Test func documentedRentalOpensTheApp() {
        #expect(LaunchGate.signedInDestination(state(documented: 1)) == .app)
    }

    @Test func firstRunReceiptStaysUntilDismissed() {
        #expect(LaunchGate.signedInDestination(state(documented: 1, receipt: true)) == .firstRun)
    }

    @Test func deviceFlagOpensTheApp() {
        #expect(LaunchGate.signedInDestination(state(documented: 0, complete: true)) == .app)
    }
}
