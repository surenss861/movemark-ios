package com.surensureshkumar.movemark.domain

import java.time.LocalDate
import java.time.format.DateTimeFormatter

/*
 * MoveMark — a rental's move-in and lease dates (iOS CreatePropertyInput / EditPropertyView). Stored in
 * `properties.move_in_date`, `lease_start`, `lease_end` as `yyyy-MM-dd` (iOS `dbDateFormatter`); the reports read
 * them from there. First-run setup asks only for the move-in date and leaves the lease unset; adding a rental asks
 * for all three; editing saves the lease only when the rental had one or a lease date was changed.
 */
object RentalDates {
    private val DB: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE

    fun format(date: LocalDate): String = DB.format(date)

    /** Reads `yyyy-MM-dd` (or the date part of a timestamp); null when blank or unreadable. */
    fun parse(raw: String?): LocalDate? = raw?.trim()?.takeIf { it.length >= 10 }?.let { runCatching { LocalDate.parse(it.take(10), DB) }.getOrNull() }

    /** The lease can't end before it starts (compared by day). */
    fun leaseDatesError(start: LocalDate?, end: LocalDate?): String? =
        if (start != null && end != null && end.isBefore(start)) "The lease end date can’t be before the lease start date." else null

    /** The picker's starting value for a lease end when none was entered: a year after the start. */
    fun defaultLeaseEnd(start: LocalDate): LocalDate = start.plusYears(1)

    /** Edit: lease dates are saved when the rental had a lease or the renter changed either date. */
    fun savesLease(hadLease: Boolean, start: LocalDate?, end: LocalDate?, initialStart: LocalDate?, initialEnd: LocalDate?): Boolean =
        hadLease || start != initialStart || end != initialEnd

    /** "Oct 24, 2026" for the date rows. */
    fun display(date: LocalDate): String = DateTimeFormatter.ofPattern("MMM d, yyyy", java.util.Locale.US).format(date)
}
