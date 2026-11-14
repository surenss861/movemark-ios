package com.surensureshkumar.movemark.features.proof

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode

/** The receipt never shows a device time as the server's: without the server's created_at it says "on this device". */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ReceiptSavedTimeTest {
    @get:Rule val compose = createComposeRule()

    private fun show(fromServer: Boolean) = compose.setContent {
        SavedProofReceiptContent(
            state = SavedProofReceiptUiState(
                roomName = "Kitchen", savedCount = 2, attemptedCount = 2, primaryActionLabel = "Continue to next room",
                savedTimeLabel = "Nov 14, 5:13 AM", savedTimeFromServer = fromServer,
            ),
            teen = false, onPrimary = {}, onViewEvidence = {}, onAddMorePhotos = {},
        )
    }

    @Test fun aServerTimeIsShownAsIs() {
        show(fromServer = true)
        compose.onNodeWithText("Nov 14, 5:13 AM").assertExists()
        compose.onNodeWithText("Confirmed Nov 14, 5:13 AM on this device").assertDoesNotExist()
    }

    @Test fun aDeviceTimeIsLabelledOnThisDevice() {
        show(fromServer = false)
        compose.onNodeWithText("Confirmed Nov 14, 5:13 AM on this device").assertExists()
    }
}
