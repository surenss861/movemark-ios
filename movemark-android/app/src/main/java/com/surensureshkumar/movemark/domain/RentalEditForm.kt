package com.surensureshkumar.movemark.domain

import com.surensureshkumar.movemark.data.models.PropertyRow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The `properties` columns Edit rental writes (lease and move-in dates are left as they are). */
@Serializable
data class PropertyPatch(
    val title: String,
    @SerialName("address_line_1") val addressLine1: String,
    @SerialName("address_line_2") val addressLine2: String?,
    val city: String,
    @SerialName("province_state") val provinceState: String,
    @SerialName("postal_code") val postalCode: String,
    val country: String,
    @SerialName("landlord_name") val landlordName: String?,
    @SerialName("landlord_email") val landlordEmail: String?,
    @SerialName("landlord_phone") val landlordPhone: String?,
    @SerialName("deposit_amount") val depositAmount: Double?,
    @SerialName("rent_amount") val rentAmount: Double?,
)

/**
 * Edit rental (iOS `EditPropertyView`): the rental's fields as editable text, iOS's validation, and the patch to
 * save. A name that only repeats the street stays blank, so it keeps following the address.
 */
data class RentalEditForm(
    val name: String = "",
    val addressLine1: String = "",
    val unit: String = "",
    val city: String = "",
    val region: String = "",
    val postalCode: String = "",
    val country: String = "CA",
    val landlordName: String = "",
    val landlordEmail: String = "",
    val landlordPhone: String = "",
    val depositAmount: String = "",
    val rentAmount: String = "",
) {
    /** Blocks the save: the address is required. */
    val validationError: String?
        get() = if (addressLine1.isBlank()) "Enter the property address." else null

    /** An optional detail that can't be saved as typed; a value left as it was isn't held against the save. */
    fun detailsIssue(initial: RentalEditForm): String? =
        emailIssue(landlordEmail.takeIf { it != initial.landlordEmail }.orEmpty())
            ?: amountIssue(depositAmount.takeIf { it != initial.depositAmount }.orEmpty())
            ?: amountIssue(rentAmount.takeIf { it != initial.rentAmount }.orEmpty())

    fun canSave(initial: RentalEditForm): Boolean = validationError == null && detailsIssue(initial) == null

    fun toPatch(): PropertyPatch {
        val street = addressLine1.trim()
        return PropertyPatch(
            title = name.trim().ifEmpty { street },
            addressLine1 = street,
            addressLine2 = unit.trim().ifEmpty { null },
            // NOT NULL columns: blank goes back to the placeholder setup writes.
            city = city.trim().ifEmpty { "Unknown" },
            provinceState = region.trim().ifEmpty { "Unknown" },
            postalCode = postalCode.trim().ifEmpty { "00000" },
            country = country.trim().ifEmpty { "CA" },
            landlordName = landlordName.trim().ifEmpty { null },
            landlordEmail = landlordEmail.trim().ifEmpty { null },
            landlordPhone = landlordPhone.trim().ifEmpty { null },
            depositAmount = parseAmount(depositAmount),
            rentAmount = parseAmount(rentAmount),
        )
    }

    companion object {
        fun from(row: PropertyRow): RentalEditForm {
            val title = row.title.trim()
            val street = row.addressLine1.trim()
            return RentalEditForm(
                name = if (title == street) "" else row.title,
                addressLine1 = row.addressLine1,
                unit = row.addressLine2.orEmpty(),
                city = meaningful(row.city),
                region = meaningful(row.provinceState),
                postalCode = meaningful(row.postalCode),
                country = row.country.ifBlank { "CA" },
                landlordName = row.landlordName.orEmpty(),
                landlordEmail = row.landlordEmail.orEmpty(),
                landlordPhone = row.landlordPhone.orEmpty(),
                depositAmount = row.depositAmount?.let(::amountText).orEmpty(),
                rentAmount = row.rentAmount?.let(::amountText).orEmpty(),
            )
        }

        /** Setup's placeholders ("Unknown", "00000") read as blank (iOS `RentalLocation.meaningful`). */
        fun meaningful(raw: String): String = raw.trim().takeUnless { it.equals("Unknown", true) || it == "00000" || it == "Address" }.orEmpty()

        fun emailIssue(raw: String): String? {
            val email = raw.trim()
            if (email.isEmpty()) return null
            return if (Regex("""^[^@\s]+@[^@\s]+\.[^@\s]{2,}$""").matches(email)) null else "Check the email address."
        }

        fun amountIssue(raw: String): String? {
            if (raw.isBlank()) return null
            val value = parseAmount(raw)
            return if (value == null || value < 0) "Enter an amount, like 1500." else null
        }

        /** "$1,500.00" → 1500.0; null when blank or not a number. */
        fun parseAmount(raw: String): Double? {
            val cleaned = raw.trim().replace(",", "").removePrefix("$").trim()
            if (cleaned.isEmpty()) return null
            return cleaned.toDoubleOrNull()
        }

        private fun amountText(value: Double): String =
            if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
    }
}
