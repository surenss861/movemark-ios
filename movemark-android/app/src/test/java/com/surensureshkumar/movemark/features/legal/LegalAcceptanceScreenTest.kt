package com.surensureshkumar.movemark.features.legal

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.legal.LegalAgeBand
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** The age-range step on the agreement screen (iOS `testLegalGateAgeRange` behaviour). */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LegalAcceptanceScreenTest {
    @get:Rule val compose = createComposeRule()
    private val accepted = mutableListOf<LegalAgeBand?>()

    private fun show(state: LegalGateState = LegalGateState(required = true, ageRequirement = "bands_v1")) =
        compose.setContent {
            LegalAcceptanceScreen(state = state, onAccept = { accepted += it }, onSignOut = {}, onDeleteAccount = {})
        }

    private fun tap(tag: String) = compose.onNodeWithTag(tag).performScrollTo().performClick()
    private fun agree() = compose.onNodeWithText(LEGAL_CONSENT_TEXT).performScrollTo().performClick()
    private fun continueButton() = compose.onNodeWithText("Continue to my Vault")

    @Test fun under13IsNotAvailableAndSendsNothing() {
        show()
        agree()
        tap("legal.age.Under13")
        compose.onNodeWithTag("legal.age.unavailable").assertExists()
        continueButton().assertIsNotEnabled()
        continueButton().performClick()
        assertTrue(accepted.isEmpty())
    }

    @Test fun thirteenInQuebecIsNotAvailable() {
        show()
        agree()
        tap("legal.age.Thirteen")
        continueButton().assertIsNotEnabled() // Quebec not answered yet
        tap("legal.age.quebec.yes")
        compose.onNodeWithTag("legal.age.unavailable").assertExists()
        continueButton().assertIsNotEnabled()
    }

    @Test fun thirteenOutsideQuebecIsATeenWithTheTeenNotice() {
        show()
        agree()
        tap("legal.age.Thirteen")
        tap("legal.age.quebec.no")
        compose.onNodeWithText(LEGAL_TEEN_NOTICE).assertExists()
        continueButton().performClick()
        assertEquals(listOf<LegalAgeBand?>(LegalAgeBand.Teen), accepted)
    }

    @Test fun adultsGetTheAdultNoticeAndTheAdultRange() {
        show()
        tap("legal.age.Adult")
        continueButton().assertIsNotEnabled() // terms not agreed yet
        agree()
        compose.onNodeWithText(LEGAL_ADULT_NOTICE).assertExists()
        continueButton().performClick()
        assertEquals(listOf<LegalAgeBand?>(LegalAgeBand.Adult), accepted)
    }

    @Test fun aServerWithoutTheAgeGateShowsNoQuestion() {
        show(LegalGateState(required = true))
        compose.onNodeWithText("How old are you?").assertDoesNotExist()
        agree()
        continueButton().performClick()
        assertEquals(listOf<LegalAgeBand?>(null), accepted)
    }

    @Test fun anUnknownAgeCodeAsksForAnUpdate() {
        show(LegalGateState(required = true, ageRequirement = "age_18"))
        compose.onNodeWithText(LegalGateViewModel.UPDATE_APP).assertExists()
        agree()
        continueButton().assertIsNotEnabled()
    }
}
