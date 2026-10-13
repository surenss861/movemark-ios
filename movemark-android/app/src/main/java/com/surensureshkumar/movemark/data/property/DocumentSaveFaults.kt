package com.surensureshkumar.movemark.data.property

/**
 * Failure injection for document saves. Release builds bind a version that never fails
 * (src/release); debug builds bind one driven by a debug preference (src/debug).
 */
fun interface DocumentSaveFaults {
    /** True once to make the next record insert fail after its file uploaded. */
    fun failNextInsert(): Boolean
}
