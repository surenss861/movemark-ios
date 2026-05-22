package com.surensureshkumar.movemark.core.navigation

object Routes {
    const val Welcome = "welcome"
    const val Auth = "auth/{mode}"

    fun auth(mode: String) = "auth/$mode"
    const val Main = "main"
    const val CreateProperty = "create_property"
    const val RoomProof = "room_proof/{roomId}"
    const val RoomProofArg = "roomId"

    fun roomProof(roomId: String) = "room_proof/$roomId"

    const val SavedProofReceipt = "saved_proof_receipt/{roomId}"
    const val SavedProofReceiptArg = "roomId"

    fun savedProofReceipt(roomId: String) = "saved_proof_receipt/$roomId"

    const val CameraCapture = "camera_capture/{roomId}"

    fun cameraCapture(roomId: String) = "camera_capture/$roomId"

    const val AddProperty = "add_property"
}

enum class MainTab { Vault, Rooms, Reports, Account }
