package com.surensureshkumar.movemark.features.property

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextReplacement
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.domain.RentalEditForm
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class EditRentalFormTest {
    @get:Rule val compose = createComposeRule()

    private fun render(initial: RentalEditForm, onForm: (RentalEditForm) -> Unit = {}) {
        var form by mutableStateOf(initial)
        compose.setContent {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                EditRentalForm(form, initial) { transform -> form = transform(form); onForm(form) }
            }
        }
    }

    @Test
    fun everyFieldEditsItsOwnValue() {
        val initial = RentalEditForm(addressLine1 = "12 Elm St", city = "Toronto")
        var form = initial
        render(initial) { form = it }
        compose.onNodeWithContentDescription("Street address").performTextReplacement("14 Oak Ave")
        compose.onNodeWithContentDescription("Rental name").performScrollTo().performTextReplacement("Lakeview")
        compose.onNodeWithContentDescription("Email").performScrollTo().performTextReplacement("pat@example.com")
        compose.onNodeWithContentDescription("Monthly rent").performScrollTo().performTextReplacement("2150")
        assertEquals("14 Oak Ave", form.addressLine1)
        assertEquals("Lakeview", form.name)
        assertEquals("pat@example.com", form.landlordEmail)
        assertEquals("2150", form.rentAmount)
        assertEquals("Toronto", form.city)
        assertEquals(2150.0, form.toPatch().rentAmount!!, 0.0)
    }

    @Test
    fun sectionsReadInIosOrderWithIosPlaceholders() {
        render(RentalEditForm(addressLine1 = ""))
        listOf("ADDRESS", "DATES", "ON YOUR RECORD", "LANDLORD", "DEPOSIT & RENT").forEach {
            compose.onNodeWithText(it).performScrollTo().assertIsDisplayed()
        }
        compose.onNodeWithText("88 Harbour St").performScrollTo().assertIsDisplayed()
        compose.onNodeWithContentDescription("Province / state").performScrollTo().assertIsDisplayed()
        compose.onNodeWithContentDescription("Postal / ZIP code").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Leave blank to use the street address").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText(RentalFormSpec.DATES_FOOTER).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun emailAndAmountIssuesShowInline() {
        render(RentalEditForm(addressLine1 = "12 Elm St", landlordEmail = "pat@", depositAmount = "lots"))
        compose.onNodeWithText("Check the email address.").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Enter an amount, like 1500.").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun otherCountryTakesACountryCode() {
        val initial = RentalEditForm(addressLine1 = "12 Elm St", country = "CA")
        var form = initial
        render(initial) { form = it }
        compose.onNodeWithContentDescription("Country, CA").performScrollTo().performClick()
        compose.onNodeWithText("Other").performClick()
        compose.onNodeWithContentDescription("Country code").performScrollTo().performTextReplacement("FR")
        assertEquals("FR", form.country)
        assertEquals("FR", form.toPatch().country)
    }
}
