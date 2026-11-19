package com.surensureshkumar.movemark.features.property

import com.surensureshkumar.movemark.domain.RentalEditForm

/**
 * The Edit rental form's layout and inline rules (iOS `RentalFormFields`): the section order, the country picker's
 * options, and the notes shown under a field that can't be saved as typed. Pure, so it is unit-tested.
 */
object RentalFormSpec {
    /** Section captions, in order (shown uppercased). */
    val sections = listOf("Address", "Dates", "On your record", "Landlord", "Deposit & rent")

    const val INTRO = "Rooms, photos and records stay exactly as they are."
    const val DATES_FOOTER = "Your move-in date anchors the record: proof captured around it shows the condition you moved into."
    const val DISCARD_TITLE = "Discard changes?"

    /** The picker's fixed countries; anything else is "Other" with a typed country code. */
    val supportedCountries = listOf("CA", "US", "GB", "AU", "NZ")
    const val OTHER = "Other"
    val countryOptions = supportedCountries + OTHER

    /** What a picker row reads as: the country's name, never its raw code ("CA" reads "Canada"). */
    fun countryName(option: String): String = when (option) {
        "CA" -> "Canada"
        "US" -> "United States"
        "GB" -> "United Kingdom"
        "AU" -> "Australia"
        "NZ" -> "New Zealand"
        else -> option
    }

    /** The picker row for a stored country: a fixed code, else "Other" (iOS `EditPropertyView.init`). */
    fun countryOption(country: String): String {
        val stored = country.trim().ifEmpty { "CA" }
        return if (stored in supportedCountries) stored else OTHER
    }

    /** The "Country code" field's text for a stored country: blank for a fixed code, else the stored value. */
    fun customCountry(country: String): String =
        if (countryOption(country) == OTHER) country.trim() else ""

    /** Picking a row: a fixed code is the country; "Other" keeps a typed code, else starts blank. */
    fun choose(option: String, form: RentalEditForm): RentalEditForm = when {
        option != OTHER -> form.copy(country = option)
        countryOption(form.country) == OTHER -> form
        else -> form.copy(country = "")
    }

    /** The row the picker shows: "Other" stays chosen while its code is still blank (blank alone reads as CA). */
    fun shownOption(country: String, otherChosen: Boolean): String =
        if (otherChosen) OTHER else countryOption(country)

    /** Inline notes (iOS `RentalFormFields.fieldIssue`): shown under the field once it is left. */
    fun emailIssue(form: RentalEditForm): String? = RentalEditForm.emailIssue(form.landlordEmail)
    fun depositIssue(form: RentalEditForm): String? = RentalEditForm.amountIssue(form.depositAmount)
    fun rentIssue(form: RentalEditForm): String? = RentalEditForm.amountIssue(form.rentAmount)

    /** The notice above Save: the save's own failure first, else a lease that ends before it starts. */
    fun notice(saveError: String?, form: RentalEditForm, initial: RentalEditForm): String? =
        saveError ?: form.leaseError(initial) ?: form.countryIssue
}
