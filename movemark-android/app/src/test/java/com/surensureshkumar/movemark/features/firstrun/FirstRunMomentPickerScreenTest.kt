package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** iOS FirstRunMomentPickerView: the first-run start, in place of the old name step. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FirstRunMomentPickerScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun showsTheMomentQuestionNotTheNameStep() {
        compose.setContent { FirstRunMomentPickerScreen(isPreparing = false, onSelect = {}, onSignOut = {}) }
        compose.onNodeWithText("What are you documenting?").assertExists()
        compose.onNodeWithText("We’ll start you in the right proof flow.").assertExists()
        compose.onNodeWithText("Moving into a rental", substring = true).assertExists()
        compose.onNodeWithText("Moving out", substring = true).assertExists()
        compose.onNodeWithText("What should we call you?").assertDoesNotExist()
    }

    @Test
    fun choosingAMomentReportsIt() {
        val chosen = mutableListOf<RentalMoment>()
        compose.setContent { FirstRunMomentPickerScreen(isPreparing = false, onSelect = { chosen += it }) }
        compose.onNodeWithTag("firstRun.moment.movingOut").performClick()
        compose.onNodeWithTag("firstRun.moment.justMovedIn").performClick()
        assertEquals(listOf(RentalMoment.MovingOut, RentalMoment.JustMovedIn), chosen)
    }

    @Test
    fun whileRentalsLoadTheChoicesWaitAndSayWhy() {
        val chosen = mutableListOf<RentalMoment>()
        compose.setContent { FirstRunMomentPickerScreen(isPreparing = true, onSelect = { chosen += it }) }
        compose.onNodeWithText(FIRST_RUN_LOADING_RENTALS).assertExists()
        compose.onNodeWithTag("firstRun.moment.justMovedIn").assertIsNotEnabled()
        assertEquals(emptyList<RentalMoment>(), chosen)
    }

    @Test
    fun signOutIsTheWayOut() {
        var signOuts = 0
        compose.setContent { FirstRunMomentPickerScreen(isPreparing = false, onSelect = {}, onSignOut = { signOuts++ }) }
        compose.onNodeWithTag("firstRun.signOut").performClick()
        assertEquals(1, signOuts)
    }
}
