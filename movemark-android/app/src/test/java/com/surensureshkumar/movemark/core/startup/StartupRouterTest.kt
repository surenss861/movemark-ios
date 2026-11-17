package com.surensureshkumar.movemark.core.startup

import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.core.startup.StartupDestination as D
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * UNKNOWN ≠ INCOMPLETE. Galaxy A14, build 2026111302: signed in, legal accepted, name done, a save interrupted, then
 * an offline launch landed on "What should we call you?" because a failed name lookup read as "no name".
 *
 * iOS 1.4 has no name step: first run ("What are you documenting?") is the only onboarding, and the name no longer
 * routes anywhere. First run opens only on a confirmed answer: the server's empty rental listing, or a loaded rental
 * whose first room is confirmed not done.
 */
class StartupRouterTest {
    private fun route(
        legal: LegalRouting = LegalRouting.Clear,
        rental: RentalStatus = RentalStatus.HasRental,
        firstRun: FirstRunStatus = FirstRunStatus.Complete,
        auth: AuthState = AuthState.SignedIn,
    ) = StartupRouter.resolve(auth, legal, rental, firstRun)

    // --- Offline launch, per gate ---

    @Test
    fun a14ReproOfflineLaunchWithARentalOnThisDeviceOpensTheVaultNotFirstRun() {
        // Whatever the name lookup did, the rental came from the cache and its first room is done.
        assertEquals(D.Main, route(rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Complete))
    }

    @Test
    fun offlineLegalStatusOpensOnTheCacheAndNeverShowsTheAgreement() {
        // LegalGateState.from(Offline) is required = false: the server enforces.
        assertEquals(LegalRouting.Clear, StartupRouter.legal(required = false, statusUnavailable = false))
        assertEquals(D.Main, route(legal = StartupRouter.legal(false, false)))
    }

    @Test
    fun failedRentalListingIsTheOfflineStateNeverFirstRun() {
        assertEquals(D.Offline, route(rental = RentalStatus.Unavailable))
        for (firstRun in FirstRunStatus.entries) {
            assertEquals(D.Offline, route(rental = RentalStatus.Unavailable, firstRun = firstRun))
        }
    }

    @Test
    fun firstRoomStepUnknownHoldsInsteadOfOpeningFirstRun() {
        assertEquals(D.Hold, route(firstRun = FirstRunStatus.Unknown))
    }

    // --- Slow lookups ---

    @Test
    fun slowLookupsHoldAndNeverRouteToFirstRun() {
        assertEquals(D.Hold, route(legal = LegalRouting.Pending, rental = RentalStatus.Unknown))
        assertEquals(D.Hold, route(rental = RentalStatus.Unknown))
        for (firstRun in FirstRunStatus.entries) {
            assertEquals(D.Hold, route(rental = RentalStatus.Unknown, firstRun = firstRun))
        }
    }

    @Test
    fun restoringAuthHolds() {
        assertEquals(D.Hold, route(auth = AuthState.Loading, rental = RentalStatus.NoRental))
    }

    @Test
    fun definitivelySignedOutGoesToSignIn() {
        assertEquals(D.SignIn, route(auth = AuthState.SignedOut))
    }

    // --- Reconnect recovery ---

    @Test
    fun reconnectTakesTheOfflineStateToTheVault() {
        assertEquals(D.Offline, route(rental = RentalStatus.Unavailable, firstRun = FirstRunStatus.Unknown))
        // Back online: the rental confirms, and the first-room step follows from the loaded rental.
        assertEquals(D.Main, route(rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Complete))
    }

    @Test
    fun reconnectRevealsAGenuinelyNewAccountAndThenFirstRunShows() {
        assertEquals(D.Offline, route(rental = RentalStatus.Unavailable))
        assertEquals(D.Onboarding, route(rental = RentalStatus.NoRental, firstRun = FirstRunStatus.Unknown))
    }

    @Test
    fun legalStatusUnavailableRetriesToTheVault() {
        assertEquals(D.LegalStatusUnavailable, route(legal = StartupRouter.legal(null, statusUnavailable = true)))
        assertEquals(D.Main, route(legal = StartupRouter.legal(false, statusUnavailable = false)))
    }

    // --- Genuine requirements are never skipped ---

    @Test
    fun genuinelyNewAccountSeesTheMomentPicker() {
        // The server listed no rentals: "What are you documenting?". The first-room status is Unknown without a rental.
        assertEquals(D.Onboarding, route(rental = RentalStatus.NoRental, firstRun = FirstRunStatus.Unknown))
        for (firstRun in FirstRunStatus.entries) {
            assertEquals(D.Onboarding, route(rental = RentalStatus.NoRental, firstRun = firstRun))
        }
    }

    @Test
    fun rentalWithTheFirstRoomNotDoneReopensFirstRun() {
        // iOS keeps first run up until the first proof is saved; the moment then goes straight to the room pick.
        assertEquals(D.Onboarding, route(rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Incomplete))
    }

    @Test
    fun existingRentalWithProofNeverSeesFirstRun() {
        assertEquals(D.Main, route(rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Complete))
        assertNotEquals(D.Onboarding, route(rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Complete))
    }

    @Test
    fun unacceptedAccountSeesTheAgreementBeforeAnythingElse() {
        assertEquals(LegalRouting.Required, StartupRouter.legal(required = true, statusUnavailable = false))
        for (rental in RentalStatus.entries) for (firstRun in FirstRunStatus.entries) {
            assertEquals(D.LegalAcceptance, route(legal = LegalRouting.Required, rental = rental, firstRun = firstRun))
        }
    }

    @Test
    fun legalPendingHolds() {
        assertEquals(LegalRouting.Pending, StartupRouter.legal(required = null, statusUnavailable = false))
        assertEquals(D.Hold, route(legal = LegalRouting.Pending))
        assertEquals(D.Hold, route(legal = LegalRouting.Pending, rental = RentalStatus.NoRental))
    }

    // --- The rule, over every combination ---

    @Test
    fun incompleteStepsOpenOnlyOnAConfirmedAnswer() {
        for (auth in AuthState.entries) for (legal in LegalRouting.entries)
            for (rental in RentalStatus.entries) for (firstRun in FirstRunStatus.entries) {
                val d = route(legal, rental, firstRun, auth)
                val label = "$auth/$legal/$rental/$firstRun -> $d"
                if (d == D.LegalAcceptance) assertEquals(label, LegalRouting.Required, legal)
                if (d == D.Onboarding) {
                    assertEquals(label, AuthState.SignedIn, auth)
                    assertEquals(label, LegalRouting.Clear, legal)
                    // Only a confirmed empty listing, or a loaded rental with the first room confirmed not done.
                    assertTrue(
                        label,
                        rental == RentalStatus.NoRental ||
                            (rental == RentalStatus.HasRental && firstRun == FirstRunStatus.Incomplete),
                    )
                }
                // An unknown or failed lookup never lands on first run.
                if (rental == RentalStatus.Unknown || rental == RentalStatus.Unavailable) assertNotEquals(label, D.Onboarding, d)
                if (firstRun == FirstRunStatus.Unknown && rental != RentalStatus.NoRental) assertNotEquals(label, D.Onboarding, d)
                // A rental with its first room done never lands on first run.
                if (rental == RentalStatus.HasRental && firstRun == FirstRunStatus.Complete) assertNotEquals(label, D.Onboarding, d)
            }
    }

    // --- First-room step ---

    @Test
    fun firstRunIsCompleteWithTheLocalFlagProofOrPendingPhotos() {
        assertEquals(FirstRunStatus.Complete, StartupRouter.firstRun(RentalStatus.HasRental, localFlag = true, rentalHasMoveInProof = false, pendingPhotos = 0))
        assertEquals(FirstRunStatus.Complete, StartupRouter.firstRun(RentalStatus.HasRental, localFlag = false, rentalHasMoveInProof = true, pendingPhotos = 0))
        // The A14 repro: a save interrupted before the receipt, photo still on the phone, cache without it.
        assertEquals(FirstRunStatus.Complete, StartupRouter.firstRun(RentalStatus.HasRental, localFlag = false, rentalHasMoveInProof = false, pendingPhotos = 1))
    }

    @Test
    fun firstRunIsIncompleteOnlyWithALoadedRentalAndNoProof() {
        assertEquals(FirstRunStatus.Incomplete, StartupRouter.firstRun(RentalStatus.HasRental, false, false, 0))
        for (rental in listOf(RentalStatus.Unknown, RentalStatus.Unavailable, RentalStatus.NoRental)) {
            assertEquals(FirstRunStatus.Unknown, StartupRouter.firstRun(rental, false, false, 0))
        }
    }
}
