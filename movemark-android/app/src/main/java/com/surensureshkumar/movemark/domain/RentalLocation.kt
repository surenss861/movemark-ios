package com.surensureshkumar.movemark.domain

/**
 * How a rental's city and province are shown (iOS `RentalLocation`). Older builds stored the placeholder
 * "Unknown" when a field was left blank (and a blank postal code is stored as "00000"); those rows are left as
 * they are and the placeholder is simply never displayed. A missing province is never invented: "Toronto".
 */
object RentalLocation {
    private val placeholders = setOf("unknown", "n/a", "na", "none", "-", "00000")

    /** The stored value, or null when it's blank or a placeholder. */
    fun meaningful(value: String?): String? {
        val trimmed = value.orEmpty().trim()
        return if (trimmed.isEmpty() || trimmed.lowercase() in placeholders) null else trimmed
    }

    /** "Toronto, ON", "Toronto", "ON" or "". */
    fun line(city: String?, province: String?): String =
        listOfNotNull(meaningful(city), meaningful(province)).joinToString(", ")
}
