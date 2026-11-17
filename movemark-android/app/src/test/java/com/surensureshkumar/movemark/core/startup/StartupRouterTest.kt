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
 */
class StartupRouterTest {
    private fun route(
        legal: LegalRouting = LegalRouting.Clear,
        profile: ProfileStatus = ProfileStatus.HasName,
        rental: RentalStatus = RentalStatus.HasRental,
        firstRun: FirstRunStatus = FirstRunStatus.Complete,
        auth: AuthState = AuthState.SignedIn,
    ) = StartupRouter.resolve(auth, legal, profile, rental, firstRun)

    // --- Offline launch, per gate ---

    @Test
    fun a14ReproOfflineLaunchWithNoCachedNameOpensTheVaultNotOnboarding() {
        // Name lookup failed (UnknownHostException) and this build had no cached name; the rental came from the cache.
        assertEquals(D.Main, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.HasRental))
    }

    @Test
    fun offlineLaunchWithCachedNameAndRentalOpensTheVault() {
        assertEquals(D.Main, route(profile = ProfileStatus.HasName, rental = RentalStatus.HasRental))
    }

    @Test
    fun offlineLegalStatusOpensOnTheCacheAndNeverShowsTheAgreement() {
        // LegalGateState.from(Offline) is required = false: the server enforces.
        assertEquals(LegalRouting.Clear, StartupRouter.legal(required = false, statusUnavailable = false))
        assertEquals(D.Main, route(legal = StartupRouter.legal(false, false)))
    }

    @Test
    fun failedRentalListingIsTheOfflineStateNotRentalSetup() {
        assertEquals(D.Offline, route(rental = RentalStatus.Unavailable))
        assertEquals(D.Offline, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.Unavailable))
    }

    @Test
    fun nameUnknownAndNoRentalOnThisDeviceIsTheOfflineStateNotOnboardingOrSetup() {
        assertEquals(D.Offline, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.NoRental))
    }

    @Test
    fun firstRoomStepUnknownHoldsInsteadOfOpeningThePicker() {
        assertEquals(D.Hold, route(firstRun = FirstRunStatus.Unknown))
    }

    // --- Slow lookups ---

    @Test
    fun slowLookupsHoldAndNeverRouteToAnIncompleteStep() {
        assertEquals(D.Hold, route(legal = LegalRouting.Pending, profile = ProfileStatus.Unknown, rental = RentalStatus.Unknown))
        assertEquals(D.Hold, route(profile = ProfileStatus.Unknown))
        assertEquals(D.Hold, route(profile = ProfileStatus.Unknown, rental = RentalStatus.NoRental))
        assertEquals(D.Hold, route(rental = RentalStatus.Unknown))
        assertEquals(D.Hold, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.Unknown))
    }

    @Test
    fun restoringAuthHolds() {
        assertEquals(D.Hold, route(auth = AuthState.Loading, profile = ProfileStatus.NeedsName, rental = RentalStatus.NoRental))
    }

    @Test
    fun definitivelySignedOutGoesToSignIn() {
        assertEquals(D.SignIn, route(auth = AuthState.SignedOut))
    }

    // --- Reconnect recovery ---

    @Test
    fun reconnectTakesTheOfflineStateToTheVault() {
        assertEquals(D.Offline, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.Unavailable, firstRun = FirstRunStatus.Unknown))
        // Back online: the name and the rental confirm, and the first-room step follows from the loaded rental.
        assertEquals(D.Main, route(profile = ProfileStatus.HasName, rental = RentalStatus.HasRental, firstRun = FirstRunStatus.Complete))
    }

    @Test
    fun reconnectRevealsAGenuinelyNewAccountAndThenOnboardingShows() {
        assertEquals(D.Offline, route(profile = ProfileStatus.Unavailable, rental = RentalStatus.Unavailable))
        assertEquals(D.Onboarding, route(profile = ProfileStatus.NeedsName, rental = RentalStatus.NoRental))
    }

    @Test
    fun legalStatusUnavailableRetriesToTheVault() {
        assertEquals(D.LegalStatusUnavailable, route(legal = StartupRouter.legal(null, statusUnavailable = true)))
        assertEquals(D.Main, route(legal = StartupRouter.legal(false, statusUnavailable = false)))
    }

    // --- Genuine requirements are never skipped ---

    @Test
    fun genuinelyNewAccountWithoutANameSeesTheNameScreen() {
        assertEquals(D.Onboarding, route(profile = ProfileStatus.NeedsName, rental = RentalStatus.Unknown, firstRun = FirstRunStatus.Unknown))
        assertEquals(D.Onboarding, route(profile = ProfileStatus.NeedsName, rental = RentalStatus.NoRental))
        // Even with a rental (name cleared elsewhere): the server said so this session.
        assertEquals(D.Onboarding, route(profile = ProfileStatus.NeedsName, rental = RentalStatus.HasRental))
    }

    @Test
    fun unacceptedAccountSeesTheAgreementBeforeAnythingElse() {
        assertEquals(LegalRouting.Required, StartupRouter.legal(required = true, statusUnavailable = false))
        for (profile in ProfileStatus.entries) for (rental in RentalStatus.entries) {
            assertEquals(D.LegalAcceptance, route(legal = LegalRouting.Required, profile = profile, rental = rental))
        }
    }

    @Test
    fun namedAccountWithNoRentalSetsOneUp() {
        assertEquals(D.CreateProperty, route(profile = ProfileStatus.HasName, rental = RentalStatus.NoRental))
    }

    @Test
    fun rentalWithNoFirstRoomOpensThePicker() {
        assertEquals(D.FirstRunRoomPicker, route(firstRun = FirstRunStatus.Incomplete))
    }

    @Test
    fun legalPendingHolds() {
        assertEquals(LegalRouting.Pending, StartupRouter.legal(required = null, statusUnavailable = false))
        assertEquals(D.Hold, route(legal = LegalRouting.Pending))
    }

    // --- The rule, over every combination ---

    @Test
    fun incompleteStepsOpenOnlyOnAConfirmedAnswer() {
        for (legal in LegalRouting.entries) for (profile in ProfileStatus.entries)
            for (rental in RentalStatus.entries) for (firstRun in FirstRunStatus.entries) {
                val d = route(legal, profile, rental, firstRun)
                val label = "$legal/$profile/$rental/$firstRun -> $d"
                if (d == D.LegalAcceptance) assertEquals(label, LegalRouting.Required, legal)
                if (d == D.Onboarding) assertEquals(label, ProfileStatus.NeedsName, profile)
                if (d == D.CreateProperty) {
                    assertEquals(label, RentalStatus.NoRental, rental)
                    assertEquals(label, ProfileStatus.HasName, profile)
                }
                if (d == D.FirstRunRoomPicker) {
                    assertEquals(label, FirstRunStatus.Incomplete, firstRun)
                    assertEquals(label, RentalStatus.HasRental, rental)
                    assertTrue(label, profile == ProfileStatus.HasName || profile == ProfileStatus.Unavailable)
                }
                // A rental on this device never lands on onboarding or setup unless the server said the name is missing.
                if (rental == RentalStatus.HasRental && profile != ProfileStatus.NeedsName) {
                    assertNotEquals(label, D.Onboarding, d)
                    assertNotEquals(label, D.CreateProperty, d)
                }
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
