package com.surensureshkumar.movemark.features.moveout

import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.MoveOutComparison
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class MoveOutComponentsTest {
    @get:Rule val compose = createComposeRule()

    private fun entry(condition: Int, tags: List<String> = emptyList(), notes: String = "") = EvidenceRecord(
        id = UUID.randomUUID(), title = "Kitchen", notes = notes, photoCount = 2,
        photos = listOf(EvidencePhoto(UUID.randomUUID(), "a.jpg"), EvidencePhoto(UUID.randomUUID(), "b.jpg")),
        conditionRating = condition, createdAt = "2026-04-14T10:00:00Z", issueTags = tags,
    )

    private val changed = MoveOutComparison.make(
        RoomRecord(UUID.randomUUID(), "Kitchen", listOf(entry(4)), listOf(entry(2, notes = "Burn mark by the stove"))),
    )

    @Test
    fun spreadCardStatesTheChangeFirstAndOpensEachSide() {
        val opened = mutableListOf<MoveOutSide>()
        compose.setContent {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                MoveOutSpreadCard(changed, sign = { null }, justCompared = true) { opened += it }
            }
        }
        compose.onNodeWithText("CHANGED").assertIsDisplayed()
        compose.onNodeWithText("Condition Good → Below fair").assertIsDisplayed()
        compose.onNodeWithText("Move-out note: “Burn mark by the stove”").assertExists()
        compose.onNodeWithText("Compared just now").assertIsDisplayed()
        compose.onNodeWithContentDescription("Move-in photo, 2 photos").assertHasClickAction().performClick()
        compose.onNodeWithContentDescription("Move-out photo, 2 photos").performClick()
        assertEquals(listOf(MoveOutSide.MoveIn, MoveOutSide.MoveOut), opened)
    }

    @Test
    fun missingRowCapturesAndReadsAsOneButton() {
        var captured = 0
        val missing = MoveOutComparison.make(RoomRecord(UUID.randomUUID(), "Bedroom", listOf(entry(4))))
        compose.setContent { MoveOutMissingRow(missing) { captured++ } }
        compose.onNodeWithText("Bedroom", substring = true).performClick()
        assertEquals(1, captured)
    }

    @Test
    fun checklistRowIsACheckboxWithItsState() {
        var done by mutableStateOf(false)
        compose.setContent { ChecklistItemRow("Keys returned", done) { done = !done } }
        compose.onNodeWithText("Keys returned")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ToggleableState, ToggleableState.Off))
            .performClick()
        assertTrue(done)
        compose.onNodeWithText("Keys returned")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.ToggleableState, ToggleableState.On))
    }

    @Test
    fun tallyJumpsAndDisablesEmptyGroupsAtLargeFont() {
        val selected = mutableListOf<Int>()
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = 2f)) {
                MoveOutTally(changed = 2, missing = 0, unchanged = 1) { selected += it }
            }
        }
        compose.onNodeWithText("Changed").performClick()
        compose.onNodeWithText("Need proof").performClick() // 0 rooms: does nothing
        compose.onNodeWithText("Unchanged").performClick()
        assertEquals(listOf(0, 2), selected)
    }
}
