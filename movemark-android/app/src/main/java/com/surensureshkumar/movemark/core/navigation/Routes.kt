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
}

enum class MainTab { Vault, Rooms, Reports, Account }
