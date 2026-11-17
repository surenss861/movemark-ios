package com.surensureshkumar.movemark.features.documents

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.ZoneOffset
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class DocumentsContentTest {
    @get:Rule val compose = createComposeRule()

    private val lease = PropertyDocumentRow(
        id = "1", propertyId = "p", userId = "u", documentType = "lease", filePath = "u/lease.pdf",
        fileName = "lease.pdf", uploadedAt = "2025-10-19",
    )

    @Test
    fun presentRowsViewMissingRowsAddAndTheToggleRevealsOthers() {
        val events = mutableListOf<String>()
        var showAll by mutableStateOf(false)
        val model = DocumentsModel.from(listOf(lease), Locale.US, ZoneOffset.UTC)
        compose.setContent {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                DocumentsContent(
                    model = model, showAll = showAll, busyKind = null, errorMessage = "Couldn't load your records.",
                    onRetry = { events += "retry" }, onToggle = { showAll = !showAll },
                    onView = { events += "view:${it.raw}" }, onAdd = { events += "add:${it.raw}" },
                    onDelete = { events += "delete:${it.raw}" },
                )
            }
        }
        compose.onNodeWithText("Added Oct 19, 2025").assertIsDisplayed()
        compose.onNodeWithText("lease.pdf").assertIsDisplayed()
        compose.onNodeWithText("Needed · Shows what you paid, and when").assertIsDisplayed()
        compose.onNodeWithText(DocumentsModel.FOOTER).performScrollTo().assertIsDisplayed()
        compose.onNodeWithContentDescription("View Lease").performClick()
        compose.onNodeWithContentDescription("Add Deposit receipt").performClick()
        compose.onNodeWithText("Try again").performClick()

        // Replace and Delete are TalkBack actions on an added record (the long-press menu's twins).
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsActions.CustomActions)).assertCountEquals(1)

        compose.onNodeWithText(DocumentsModel.TOGGLE_DETAIL).assertIsDisplayed()
        compose.onNodeWithText(DocumentsModel.TOGGLE_MORE).performScrollTo().performClick()
        compose.onNodeWithText(VaultDocumentKind.CleaningReceipt.title).performScrollTo().assertIsDisplayed()
        compose.onNodeWithText(DocumentsModel.TOGGLE_FEWER).performScrollTo().assertIsDisplayed()
        assertEquals(listOf("view:lease", "add:deposit_receipt", "retry"), events)
    }
}
