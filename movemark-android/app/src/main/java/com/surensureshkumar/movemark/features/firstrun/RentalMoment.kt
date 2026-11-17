/**
 * @file The stage of the rental a renter is documenting (iOS RentalMoment.swift). Decides whether the first capture is
 *       move-in or move-out evidence. Two paths only: first run never routes into reports, damage or disputes.
 * @domain onboarding-auth
 * @status wip
 * @see [[FirstRunMomentPickerScreen.kt]]
 * @tested-by [[FirstRunFlowTest.kt]]
 */
package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.Key
import androidx.compose.ui.graphics.vector.ImageVector
import com.surensureshkumar.movemark.domain.ProofPhase

/**
 * Every moment still produces proof the same way (rental → room → capture); the moment decides whether the first
 * capture is recorded as move-out evidence.
 */
enum class RentalMoment(val key: String, val title: String, val blurb: String) {
    JustMovedIn("justMovedIn", "Moving into a rental", "Record how it looks before you unpack."),
    MovingOut("movingOut", "Moving out", "Compare how you’re leaving it."),
    ;

    /** iOS: shippingbox / key. */
    val icon: ImageVector
        get() = when (this) {
            JustMovedIn -> Icons.Outlined.Inventory2
            MovingOut -> Icons.Outlined.Key
        }

    /** Move-out records the first capture as move-out evidence, on the before-and-after side of the report. */
    val capturesMoveOutEvidence: Boolean get() = this == MovingOut

    /** The proof phase the first capture opens in. */
    val proofPhase: ProofPhase get() = if (capturesMoveOutEvidence) ProofPhase.MoveOut else ProofPhase.MoveIn
}
