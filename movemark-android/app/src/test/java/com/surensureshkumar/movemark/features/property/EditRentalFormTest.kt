package com.surensureshkumar.movemark.features.property

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
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

    @Test
    fun everyFieldEditsItsOwnValue() {
        val initial = RentalEditForm(addressLine1 = "12 Elm St", city = "Toronto")
        var form by mutableStateOf(initial)
        compose.setContent {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                EditRentalForm(form, initial) { transform -> form = transform(form) }
            }
        }
        compose.onNodeWithText("Street address").performTextReplacement("14 Oak Ave")
        compose.onNodeWithText("Email (optional)").performScrollTo().performTextReplacement("pat@example.com")
        compose.onNodeWithText("Monthly rent (optional)").performScrollTo().performTextReplacement("2150")
        assertEquals("14 Oak Ave", form.addressLine1)
        assertEquals("pat@example.com", form.landlordEmail)
        assertEquals("2150", form.rentAmount)
        assertEquals("Toronto", form.city)
        assertEquals(2150.0, form.toPatch().rentAmount!!, 0.0)
    }
}
