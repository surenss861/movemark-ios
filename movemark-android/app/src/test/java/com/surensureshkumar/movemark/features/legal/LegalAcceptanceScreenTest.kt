package com.surensureshkumar.movemark.features.legal

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.legal.LegalAgeBand
import com.surensureshkumar.movemark.data.legal.LegalUnavailable
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** The agreement screen under `bands_v2` (Quebec first, then the age range), `bands_v1`, single box and unknown codes. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LegalAcceptanceScreenTest {
    @get:Rule val compose = createComposeRule()
    private val accepted = mutableListOf<LegalAgeBand?>()
    private var deletes = 0
    private var signOuts = 0

    private fun show(state: LegalGateState = LegalGateState(required = true, ageRequirement = "bands_v2")) =
        compose.setContent {
            LegalAcceptanceScreen(
                state = state,
                onAccept = { accepted += it },
                onSignOut = { signOuts++ },
                onDeleteAccount = { deletes++ },
            )
        }

    private fun tap(tag: String) = compose.onNodeWithTag(tag).performScrollTo().performClick()
    private fun agree() = compose.onNodeWithText(LEGAL_CONSENT_TEXT).performScrollTo().performClick()

    @Test fun unansweredShowsOnlyTheQuebecQuestionWithNothingSelected() {
        show()
        compose.onNodeWithText("Do you live in Quebec?").assertExists()
        compose.onNodeWithTag("legal.quebec.yes").assertIsNotSelected()
        compose.onNodeWithTag("legal.quebec.no").assertIsNotSelected()
        compose.onNodeWithText("How old are you?").assertDoesNotExist()
        agree()
        compose.onNodeWithTag("legal.continue").assertIsNotEnabled()
        compose.onNodeWithTag("legal.continue").performClick()
        assertTrue(accepted.isEmpty())
    }

    @Test fun quebecYesStopsSendsNothingAndOffersDeletionNeverAutomatic() {
        show()
        agree()
        tap("legal.quebec.yes")
        compose.onNodeWithTag("legal.quebec.unavailable").assertExists()
        compose.onNodeWithText(LegalUnavailable.QUEBEC_MESSAGE).assertExists()
        compose.onNodeWithText("If you subscribed, cancel in Google Play › Subscriptions.").assertExists()
        compose.onNodeWithText("How old are you?").assertDoesNotExist()
        compose.onNodeWithTag("legal.continue").assertDoesNotExist()
        assertEquals(0, deletes) // nothing deleted on its own
        // "Delete my account" asks first; only the confirmation deletes.
        compose.onNodeWithTag("legal.delete").performClick()
        compose.onNodeWithText("Delete your account?").assertExists()
        compose.onNodeWithText("Keep account").performClick()
        assertEquals(0, deletes)
        compose.onNodeWithTag("legal.delete").performClick()
        compose.onNodeWithText("Delete account").performClick()
        assertEquals(1, deletes)
        compose.onNodeWithText("Sign out").performClick()
        assertEquals(1, signOuts)
        assertTrue(accepted.isEmpty())
    }

    @Test fun under13StopsWithDeleteAsTheMainAction() {
        show()
        agree()
        tap("legal.quebec.no")
        tap("legal.age.Under13")
        compose.onNodeWithTag("legal.age.unavailable").assertExists()
        compose.onNodeWithTag("legal.delete").assertExists()
        compose.onNodeWithTag("legal.continue").assertDoesNotExist()
        assertTrue(accepted.isEmpty())
    }

    @Test fun thirteenAndFourteenToSeventeenAreTeens() {
        show()
        agree()
        tap("legal.quebec.no")
        tap("legal.age.Thirteen")
        compose.onNodeWithText(LEGAL_TEEN_NOTICE).assertExists()
        tap("legal.age.FourteenToSeventeen")
        compose.onNodeWithText(LEGAL_TEEN_NOTICE).assertExists()
        compose.onNodeWithTag("legal.continue").performClick()
        assertEquals(listOf<LegalAgeBand?>(LegalAgeBand.Teen), accepted)
    }

    @Test fun adultsGetTheAdultNoticeAndRange() {
        show()
        tap("legal.quebec.no")
        tap("legal.age.Adult")
        compose.onNodeWithTag("legal.continue").assertIsNotEnabled() // terms not agreed yet
        agree()
        compose.onNodeWithText(LEGAL_ADULT_NOTICE).assertExists()
        compose.onNodeWithTag("legal.continue").performClick()
        assertEquals(listOf<LegalAgeBand?>(LegalAgeBand.Adult), accepted)
    }

    @Test fun aRegionRefusalFromTheServerShowsTheQuebecStop() {
        show(LegalGateState(required = true, ageRequirement = "bands_v2", regionRefused = true))
        compose.onNodeWithTag("legal.quebec.unavailable").assertExists()
        compose.onNodeWithTag("legal.continue").assertDoesNotExist()
    }

    @Test fun bandsV1AsksTheSameQuestions() {
        show(LegalGateState(required = true, ageRequirement = "bands_v1"))
        tap("legal.quebec.yes")
        compose.onNodeWithTag("legal.quebec.unavailable").assertExists()
    }

    @Test fun singleBoxCodesNeedTheBox() {
        show(LegalGateState(required = true, ageRequirement = "age_18"))
        compose.onNodeWithText("Do you live in Quebec?").assertDoesNotExist()
        agree()
        compose.onNodeWithTag("legal.continue").assertIsNotEnabled()
        tap("legal.age")
        compose.onNodeWithTag("legal.continue").performClick()
        assertEquals(listOf<LegalAgeBand?>(null), accepted)
    }

    @Test fun aServerWithoutTheAgeGateShowsNoQuestion() {
        show(LegalGateState(required = true))
        compose.onNodeWithText("Do you live in Quebec?").assertDoesNotExist()
        agree()
        compose.onNodeWithTag("legal.continue").performClick()
        assertEquals(listOf<LegalAgeBand?>(null), accepted)
    }

    @Test fun anUnknownCodeAsksForAnUpdateWithExitsAvailable() {
        show(LegalGateState(required = true, ageRequirement = "bands_v3"))
        compose.onNodeWithText("Update MoveMark from the Play Store to continue.").assertExists()
        agree()
        compose.onNodeWithTag("legal.continue").assertIsNotEnabled()
        compose.onNodeWithText("Sign out").assertExists()
        compose.onNodeWithText("Delete account").assertExists()
    }
}
