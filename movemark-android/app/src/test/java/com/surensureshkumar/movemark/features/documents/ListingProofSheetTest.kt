package com.surensureshkumar.movemark.features.documents

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.ZoneOffset
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class ListingProofSheetTest {
    @get:Rule val compose = createComposeRule()

    private fun row(
        type: String = "listing_screenshot",
        filePath: String = "u/listing.jpg",
        thumbnailPath: String? = null,
        uploadedAt: String? = "2025-10-12T14:03:00Z",
    ) = PropertyDocumentRow(
        id = "l1", propertyId = "p", userId = "u", documentType = type, filePath = filePath,
        fileName = "IMG_0001.jpg", uploadedAt = uploadedAt, thumbnailPath = thumbnailPath,
    )

    @Test
    fun archivedListingShowsSourceMaterialAndReplaceCallsBack() {
        val events = mutableListOf<String>()
        val current = ListingProof.current(listOf(row()), Locale.US, ZoneOffset.UTC)
        compose.setContent {
            ListingProofSheetContent(
                current = current,
                imageUrl = null,
                imageFailed = false,
                onReplace = { events += "replace" },
                onCancel = { events += "cancel" },
            )
        }
        compose.onNodeWithText("Listing proof").assertIsDisplayed()
        compose.onNodeWithText("How the rental was advertised, kept with your record as source material.").assertIsDisplayed()
        compose.onNodeWithContentDescription("Original listing image").assertExists()
        compose.onNodeWithText("Original listing", useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Added Oct 12, 2025", useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Source preserved", useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("The current image stays on file until the new one is saved.").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Replace screenshot").performScrollTo().performClick()
        compose.onNodeWithText("Cancel").performClick()
        assertEquals(listOf("replace", "cancel"), events)
    }

    @Test
    fun emptyListingExplainsWhyAndOffersChooseScreenshot() {
        val events = mutableListOf<String>()
        compose.setContent {
            ListingProofSheetContent(
                current = null,
                imageUrl = null,
                imageFailed = false,
                onReplace = { events += "choose" },
                onCancel = {},
            )
        }
        compose.onNodeWithText("Listing proof").assertIsDisplayed()
        compose.onNodeWithText(ListingProof.INTRO_EMPTY).assertIsDisplayed()
        compose.onNodeWithText("No listing saved yet").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Original listing").assertDoesNotExist()
        compose.onNodeWithText("Source preserved").assertDoesNotExist()
        compose.onNodeWithText("Saved as you chose it, with the date it was added.").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Choose screenshot").performScrollTo().performClick()
        assertEquals(listOf("choose"), events)
    }

    @Test
    fun failedImageStillShowsTheRecordWithoutTheDateWhenUnreadable() {
        val current = ListingProof.Current(path = "u/listing.pdf", addedOn = null)
        compose.setContent {
            ListingProofSheetContent(current = current, imageUrl = null, imageFailed = true, onReplace = {}, onCancel = {})
        }
        compose.onNodeWithContentDescription("Original listing image").assertExists()
        compose.onNodeWithText("Original listing", useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Added", substring = true, useUnmergedTree = true).assertDoesNotExist()
        compose.onNodeWithText("Replace screenshot").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun currentPrefersTheThumbnailAndReadsTheHyphenatedType() {
        val current = ListingProof.current(
            listOf(row(type = "listing-screenshot", thumbnailPath = "u/listing_thumb.jpg")),
            Locale.US,
            ZoneOffset.UTC,
        )
        assertEquals("u/listing_thumb.jpg", current?.path)
        assertEquals("Added Oct 12, 2025", current?.addedLine)
    }

    @Test
    fun currentFallsBackToTheFileAndIsNullWithoutAListingRow() {
        val current = ListingProof.current(listOf(row(thumbnailPath = "  ", uploadedAt = "not a date")), Locale.US, ZoneOffset.UTC)
        assertEquals("u/listing.jpg", current?.path)
        assertNull(current?.addedLine)
        assertNull(ListingProof.current(listOf(row(type = "lease")), Locale.US, ZoneOffset.UTC))
        assertNull(ListingProof.current(emptyList()))
    }

    @Test
    fun copyFollowsWhetherAListingIsOnFile() {
        val current = ListingProof.Current("p", "Oct 12, 2025")
        assertEquals(ListingProof.ACTION_REPLACE, ListingProof.action(current))
        assertEquals(ListingProof.ACTION_CHOOSE, ListingProof.action(null))
        assertEquals(ListingProof.CAPTION_CURRENT, ListingProof.caption(current))
        assertEquals(ListingProof.CAPTION_EMPTY, ListingProof.caption(null))
        assertEquals(ListingProof.INTRO_CURRENT, ListingProof.intro(current))
        assertEquals(ListingProof.INTRO_EMPTY, ListingProof.intro(null))
    }
}
