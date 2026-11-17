/**
 * @file The one place that decides where a launch lands. Every launch gate (legal, name, rental, first room) reports a
 *       status that keeps "we don't know yet / couldn't check" apart from "the server said this step is incomplete".
 *       The rule: UNKNOWN ≠ INCOMPLETE. A failed or missing lookup never routes into onboarding, rental setup or the
 *       first-room picker, and a genuine first-run requirement is never skipped.
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupCoordinator.kt]]
 * @tested-by [[StartupRouterTest.kt]]
 */
package com.surensureshkumar.movemark.core.startup

import com.surensureshkumar.movemark.data.auth.AuthState

/** The renter's name, as far as this launch knows it. */
enum class ProfileStatus {
    /** Not looked up yet, and nothing cached for this account. */
    Unknown,
    /** A name is on file: confirmed by the server, or by the last confirmed answer cached on this device. */
    HasName,
    /** The server answered, this session, that the account has no name yet. The only state that opens onboarding. */
    NeedsName,
    /** The lookup failed (offline, timeout, server error) and nothing is cached. Not the same as [NeedsName]. */
    Unavailable,
}

/** Whether the renter has a rental, as far as this launch knows it. */
enum class RentalStatus {
    Unknown,
    /** A rental is loaded: from the server, or from this device's cache of the last successful load. */
    HasRental,
    /** The server's listing answered, this session, with no rentals. The only state that opens rental setup. */
    NoRental,
    /** The listing failed and nothing usable is cached. Not the same as [NoRental]. */
    Unavailable,
}

/** Whether the first-room step is behind the renter. */
enum class FirstRunStatus { Unknown, Complete, Incomplete }

/** The legal gate's answer, reduced to what routing needs (see LegalGateState). */
enum class LegalRouting {
    /** Waiting for the first answer. */
    Pending,
    /** Not required, or the status couldn't be reached (the server enforces; the app opens on its cache). */
    Clear,
    /** The server says this account must agree. */
    Required,
    /** The server answered with an error: "Can't open your Vault yet". */
    StatusUnavailable,
}

enum class StartupDestination {
    /** Keep whatever is on screen (restoring auth, or a lookup still in flight). */
    Hold,
    SignIn,
    LegalAcceptance,
    LegalStatusUnavailable,
    Onboarding,
    CreateProperty,
    FirstRunRoomPicker,
    Main,
    /** Couldn't reach MoveMark and nothing on this device says where to go: a recoverable state with a retry. */
    Offline,
}

object StartupRouter {
    /** The legal gate's state (LegalGateState.required / statusUnavailable) as routing sees it. */
    fun legal(required: Boolean?, statusUnavailable: Boolean): LegalRouting = when {
        statusUnavailable -> LegalRouting.StatusUnavailable
        required == null -> LegalRouting.Pending
        required -> LegalRouting.Required
        else -> LegalRouting.Clear
    }

    fun resolve(
        auth: AuthState,
        legal: LegalRouting,
        profile: ProfileStatus,
        rental: RentalStatus,
        firstRun: FirstRunStatus,
    ): StartupDestination = when (auth) {
        AuthState.Loading -> StartupDestination.Hold
        AuthState.SignedOut -> StartupDestination.SignIn
        AuthState.SignedIn -> signedIn(legal, profile, rental, firstRun)
    }

    private fun signedIn(
        legal: LegalRouting,
        profile: ProfileStatus,
        rental: RentalStatus,
        firstRun: FirstRunStatus,
    ): StartupDestination {
        when (legal) {
            LegalRouting.StatusUnavailable -> return StartupDestination.LegalStatusUnavailable
            LegalRouting.Pending -> return StartupDestination.Hold
            LegalRouting.Required -> return StartupDestination.LegalAcceptance
            LegalRouting.Clear -> Unit
        }
        when (profile) {
            ProfileStatus.NeedsName -> return StartupDestination.Onboarding
            ProfileStatus.Unknown -> return StartupDestination.Hold
            // A name we couldn't check is not a missing name. With a rental on this device the renter goes on to it;
            // without one there is no way to tell a new account from an offline one, so: the offline state.
            ProfileStatus.Unavailable -> if (rental != RentalStatus.HasRental) {
                return if (rental == RentalStatus.Unknown) StartupDestination.Hold else StartupDestination.Offline
            }
            ProfileStatus.HasName -> Unit
        }
        return when (rental) {
            RentalStatus.Unknown -> StartupDestination.Hold
            RentalStatus.NoRental -> StartupDestination.CreateProperty
            RentalStatus.Unavailable -> StartupDestination.Offline
            RentalStatus.HasRental -> when (firstRun) {
                FirstRunStatus.Unknown -> StartupDestination.Hold
                FirstRunStatus.Incomplete -> StartupDestination.FirstRunRoomPicker
                FirstRunStatus.Complete -> StartupDestination.Main
            }
        }
    }

    /**
     * First-room step. Complete when this device recorded it, the loaded rental already has move-in proof, or this
     * device holds move-in photos not yet on the server (an interrupted save is proof the step was started).
     * Incomplete only when a rental is actually loaded and none of those hold.
     */
    fun firstRun(rental: RentalStatus, localFlag: Boolean, rentalHasMoveInProof: Boolean, pendingPhotos: Int): FirstRunStatus =
        when {
            localFlag || pendingPhotos > 0 -> FirstRunStatus.Complete
            rental != RentalStatus.HasRental -> FirstRunStatus.Unknown
            rentalHasMoveInProof -> FirstRunStatus.Complete
            else -> FirstRunStatus.Incomplete
        }
}
