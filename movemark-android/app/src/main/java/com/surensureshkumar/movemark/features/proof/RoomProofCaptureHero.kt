/**
 * @file Room screen hero — hosts the evidence plate
 * @domain proof-capture
 * @status wip
 * @see [[MMRoomEvidencePlate.kt]] — the plate itself
 * @see [[ROOM_EVIDENCE_RECORD]] — screen spec
 */
package com.surensureshkumar.movemark.features.proof

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.surensureshkumar.movemark.core.design.components.MMRoomEvidencePlate
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase

/**
 * iOS `ProofSprint.roomShotPrompts`, minus "Tag visible damage" and "Add notes…": Android Room
 * has no issue tags or notes yet, so it must not prompt for them.
 */
// TODO(@suren): restore the two prompts once Android Room gets condition/tags/notes parity — #high
private val roomShotPrompts = listOf(
    "Take a wide room photo",
    "Photograph walls and baseboards",
    "Photograph floors",
    "Photograph windows / blinds",
)

@Composable
fun RoomProofCaptureHero(
    roomName: String,
    room: RoomRecord?,
    proofPhase: ProofPhase,
    signPhotoUrl: suspend (String) -> String?,
    modifier: Modifier = Modifier,
) {
    MMRoomEvidencePlate(
        roomName = roomName,
        room = room,
        proofPhase = proofPhase,
        shotPrompts = roomShotPrompts,
        signPhotoUrl = signPhotoUrl,
        modifier = modifier,
    )
}
