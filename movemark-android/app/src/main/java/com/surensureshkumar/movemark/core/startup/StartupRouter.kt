/**
 * @file The one place that decides where a launch lands. Every launch gate (legal, rental, first room) reports a
 *       status that keeps "we don't know yet / couldn't check" apart from "the server said this step is incomplete".
 *       The rule: UNKNOWN ≠ INCOMPLETE. A failed or missing lookup never routes into first run (moment picker, rental
 *       setup, first-room pick), and a genuine first-run requirement is never skipped. The renter's name no longer
 *       gates anything (iOS 1.4 has no name step: identity lives in Account), so [ProfileStatus] is display-only.
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupCoordinator.kt]]
 * @tested-by [[StartupRouterTest.kt]]
 */
package com.surensureshkumar.movemark.core.startup

import com.surensureshkumar.movemark.data.auth.AuthState

/** The renter's name, as far as this launch knows it. Shown in Account; never a launch gate. */
enum class ProfileStatus {
    /** Not looked up yet, and nothing cached for this account. */
    Unknown,
    /** A name is on file: confirmed by the server, or by the last confirmed answer cached on this device. */
    HasName,
    /** The server answered, this session, that the account has no name yet (Account offers to add one). */
    NeedsName,
    /** The lookup failed (offline, timeout, server error) and nothing is cached. Not the same as [NeedsName]. */
    Unavailable,
}

/** Whether the renter has a rental, as far as this launch knows it. */
enum class RentalStatus {
    Unknown,
    /** A rental is loaded: from the server, or from this device's cache of the last successful load. */
    HasRental,
    /** The server's listing answered, this session, with no rentals. The state that opens first run for a new account. */
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
    /**
     * First run (iOS FirstRunProofFlowView, "What are you documenting?"): moment → rental setup → first room. Only on a
     * confirmed answer: the server's empty rental listing, or a loaded rental whose first room is confirmed not done.
     */
    Onboarding,
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
        rental: RentalStatus,
        firstRun: FirstRunStatus,
    ): StartupDestination = when (auth) {
        AuthState.Loading -> StartupDestination.Hold
        AuthState.SignedOut -> StartupDestination.SignIn
        AuthState.SignedIn -> signedIn(legal, rental, firstRun)
    }

    private fun signedIn(
        legal: LegalRouting,
        rental: RentalStatus,
        firstRun: FirstRunStatus,
    ): StartupDestination {
        when (legal) {
            LegalRouting.StatusUnavailable -> return StartupDestination.LegalStatusUnavailable
            LegalRouting.Pending -> return StartupDestination.Hold
            LegalRouting.Required -> return StartupDestination.LegalAcceptance
            LegalRouting.Clear -> Unit
        }
        // iOS opens first run (needsOnboarding) until the first proof is saved, and opens the app when the profile
        // couldn't be read. Here: first run on a confirmed empty listing or a confirmed-incomplete first room; a listing
        // that failed is the offline state, one still loading holds.
        return when (rental) {
            RentalStatus.Unknown -> StartupDestination.Hold
            RentalStatus.NoRental -> StartupDestination.Onboarding
            RentalStatus.Unavailable -> StartupDestination.Offline
            RentalStatus.HasRental -> when (firstRun) {
                FirstRunStatus.Unknown -> StartupDestination.Hold
                FirstRunStatus.Incomplete -> StartupDestination.Onboarding
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
