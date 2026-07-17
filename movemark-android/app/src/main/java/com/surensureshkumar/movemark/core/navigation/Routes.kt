package com.surensureshkumar.movemark.core.navigation

import com.surensureshkumar.movemark.domain.ProofPhase

object Routes {
    const val Welcome = "welcome"
    const val Auth = "auth/{mode}"

    fun auth(mode: String) = "auth/$mode"
    const val Main = "main"
    const val Onboarding = "onboarding"
    const val CreateProperty = "create_property"
    const val FirstRunRoomPicker = "first_run_room_picker"
    const val AddProperty = "add_property"

    const val MaintenanceLog = "maintenance_log"
    const val MaintenanceIssueArg = "issueId"
    const val MaintenanceIssueDetail = "maintenance_issue/{issueId}"

    fun maintenanceIssueDetail(issueId: String) = "maintenance_issue/$issueId"

    const val ProofPhaseArg = "proofPhase"
    const val RoomProofArg = "roomId"
    const val RoomProof = "room_proof/{proofPhase}/{roomId}"

    fun roomProof(roomId: String, phase: ProofPhase = ProofPhase.MoveIn) =
        "room_proof/${phase.key}/$roomId"

    const val MoveOutRooms = "move_out_rooms"

    const val SavedProofReceipt = "saved_proof_receipt/{proofPhase}/{roomId}"
    const val SavedProofReceiptArg = "roomId"

    fun savedProofReceipt(roomId: String, phase: ProofPhase = ProofPhase.MoveIn) =
        "saved_proof_receipt/${phase.key}/$roomId"

    const val CameraCapture = "camera_capture/{proofPhase}/{roomId}"

    fun cameraCapture(roomId: String, phase: ProofPhase = ProofPhase.MoveIn) =
        "camera_capture/${phase.key}/$roomId"
}

enum class MainTab { Vault, Rooms, Reports, Account }
