package com.surensureshkumar.movemark.domain

enum class ProofPhase(val key: String) {
    MoveIn("move_in"),
    MoveOut("move_out"),
    ;

    val displayName: String
        get() = when (this) {
            MoveIn -> "Move-in"
            MoveOut -> "Move-out"
        }

    val storageFolder: String
        get() = key

    companion object {
        fun fromKey(raw: String?): ProofPhase = entries.firstOrNull { it.key == raw?.lowercase() } ?: MoveIn
    }
}
