package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** iOS FirstRunRoomPickerView + FirstRunOtherRoomSheet: six options, "Other" names a room, no skip. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FirstRunRoomPickerContentTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun sixOptionsSelectOneAtATimeAndThereIsNoSkip() {
        compose.setContent {
            var selected by remember { mutableStateOf(FirstRunRoomOption.Kitchen) }
            FirstRunRoomPickerContent(
                selected = selected,
                onSelect = { selected = it },
                error = null,
                loading = false,
                canStart = true,
                onStart = {},
            )
        }
        FirstRunRoomOption.entries.forEach { compose.onNodeWithTag("firstRun.room.${it.name}").performScrollTo() }
        compose.onNodeWithTag("firstRun.room.Kitchen").assertIsSelected()
        compose.onNodeWithTag("firstRun.room.Other").performScrollTo().performClick()
        compose.onNodeWithTag("firstRun.room.Other").assertIsSelected()
        compose.onNodeWithTag("firstRun.room.Kitchen").assertIsNotSelected()
        compose.onNodeWithText("Skip for now").assertDoesNotExist()
    }

    @Test
    fun startWaitsForTheRental() {
        compose.setContent {
            FirstRunRoomPickerContent(FirstRunRoomOption.Kitchen, {}, error = null, loading = false, canStart = false, onStart = {})
        }
        compose.onNodeWithTag("firstRun.startRoomProof").performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun otherRoomSheetNeedsANameAndChipsFillIt() {
        var uses = 0
        var cancels = 0
        compose.setContent {
            var name by remember { mutableStateOf("") }
            FirstRunOtherRoomSheetContent(
                otherRoomName = name,
                onNameChange = { name = it },
                onUse = { uses++ },
                onCancel = { cancels++ },
            )
        }
        compose.onNodeWithText(OTHER_ROOM_SHEET_TITLE).assertExists()
        compose.onNodeWithText("Room name").assertExists()
        compose.onNodeWithTag("firstRun.addOtherRoom").assertIsNotEnabled()
        compose.onNodeWithText("Balcony").performClick()
        compose.onNodeWithTag("firstRun.addOtherRoom").assertIsEnabled().performClick()
        assertEquals(1, uses)
        compose.onNodeWithText("Cancel").performClick()
        assertEquals(1, cancels)
    }

    @Test
    fun typedRoomNameEnablesAddRoom() {
        compose.setContent {
            var name by remember { mutableStateOf("") }
            FirstRunOtherRoomSheetContent(otherRoomName = name, onNameChange = { name = it }, onUse = {}, onCancel = {})
        }
        compose.onNodeWithTag("firstRun.otherRoomName").performTextInput("Wine cellar")
        compose.onNodeWithTag("firstRun.addOtherRoom").assertIsEnabled()
    }
}
