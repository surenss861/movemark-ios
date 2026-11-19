package com.surensureshkumar.movemark.features.maintenance

import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class MaintenanceLogContentTest {
    @get:Rule val compose = createComposeRule()

    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale

    @Before fun pin() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        Locale.setDefault(Locale.US)
    }

    @After fun restore() {
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
    }

    private val dishwasher = MaintenanceRecord(
        UUID.nameUUIDFromBytes("m1".toByteArray()), "Dishwasher leaking", "Appliance",
        "Water pools under the door.", "open", null, 2, "2026-10-24T12:00:00Z",
    )
    private val window = MaintenanceRecord(
        UUID.nameUUIDFromBytes("m2".toByteArray()), "Bedroom window won't latch", "Structural",
        "", "follow_up", "Oct 25: Repair booked", 1, "2026-10-20T12:00:00Z",
    )
    private val fan = MaintenanceRecord(
        UUID.nameUUIDFromBytes("m3".toByteArray()), "Bathroom fan noisy", "HVAC",
        "", "resolved", "Fixed.", 0, "2026-09-10T12:00:00Z",
    )

    private fun renderList(
        log: List<MaintenanceRecord>,
        isLoading: Boolean = false,
        errorMessage: String? = null,
        events: MutableList<String> = mutableListOf(),
    ) = compose.setContent {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            MaintenanceCaseList(
                log = log,
                isLoading = isLoading,
                errorMessage = errorMessage,
                notice = null,
                covers = emptyMap(),
                onOpenIssue = { events += "open:$it" },
                onRecord = { events += "record" },
                onRetry = { events += "retry" },
            )
        }
    }

    @Test
    fun emptyLogInvitesRecordingAnIssue() {
        val events = mutableListOf<String>()
        renderList(emptyList(), events = events)
        compose.onNodeWithText("No cases recorded").assertExists()
        compose.onNodeWithText("When something happens, record it with photos and a date.").assertExists()
        compose.onNodeWithText("Record an issue").performScrollTo().performClick()
        assertEquals(listOf("record"), events)
        compose.onNodeWithText("No incidents logged yet.", substring = true).assertDoesNotExist()
    }

    @Test
    fun failedFirstLoadSaysSoAndRetries() {
        val events = mutableListOf<String>()
        renderList(emptyList(), errorMessage = "Couldn’t refresh", events = events)
        compose.onNodeWithText("Cases didn't load").assertExists()
        compose.onNodeWithText("No cases recorded").assertDoesNotExist()
        compose.onNodeWithText("Try again").performScrollTo().performClick()
        assertEquals(listOf("retry"), events)
    }

    @Test
    fun firstLoadShowsLoadingCases() {
        renderList(emptyList(), isLoading = true)
        compose.onNodeWithText("Loading cases…").assertExists()
        compose.onNodeWithText("No cases recorded").assertDoesNotExist()
    }

    @Test
    fun casesGroupIntoOpenThenResolvedWithCaseRows() {
        val events = mutableListOf<String>()
        renderList(listOf(fan, dishwasher, window), events = events)
        compose.onNodeWithText("OPEN · 2").assertExists()
        compose.onNodeWithText("RESOLVED · 1").assertExists()
        compose.onNodeWithText("Appliance · Reported Oct 24").assertExists()
        // Legacy Android category spelling reads as the iOS category.
        compose.onNodeWithText("Heating / cooling · Reported Sep 10").assertExists()
        compose.onNodeWithText("2 photos").assertExists()
        compose.onNodeWithText("No photos").assertExists()
        compose.onNodeWithContentDescription("Status: Follow-up").assertExists()
        compose.onNodeWithContentDescription("Status: Resolved").assertExists()
        // The inline composer is gone.
        compose.onNodeWithText("Log a new incident").assertDoesNotExist()
        compose.onNodeWithText("Dishwasher leaking").performScrollTo().performClick()
        assertEquals(listOf("open:${dishwasher.id}"), events)
    }

    @Test
    fun headerCarriesTheRentalAndTheRecordAction() {
        compose.setContent {
            MaintenanceLogContent(
                log = emptyList(), isLoading = false, isSubmitting = false, errorMessage = null,
                onBack = {}, onOpenIssue = {}, rentalTitle = "Maple Street Apartment",
            )
        }
        compose.onNodeWithText("MAINTENANCE").assertExists()
        compose.onNodeWithText("Maple Street Apartment").assertExists()
        compose.onNodeWithText("Issues recorded for this rental.").assertExists()
        compose.onNodeWithContentDescription("Record an issue").assertExists()
    }

    @Test
    fun newIssueFormMatchesIosAndSavesTheIosCategory() {
        var saved: MaintenanceIssueDraft? = null
        compose.setContent {
            var title by remember { mutableStateOf("") }
            var category by remember { mutableStateOf(MaintenanceCategory.Default) }
            var details by remember { mutableStateOf("") }
            MaintenanceNewIssueForm(
                title = title, onTitle = { title = it },
                category = category, onCategory = { category = it },
                details = details, onDetails = { details = it },
                photos = emptyList<Uri>(), onAttachPhotos = {},
                isSubmitting = false, errorMessage = null,
                onCancel = {},
                onSave = { saved = MaintenanceIssueDraft(title.trim(), category.raw, details.trim()) },
            )
        }
        compose.onNodeWithText("Record an issue").assertExists()
        compose.onNodeWithText("Issue title").assertExists()
        compose.onNodeWithText("Water leak under sink").assertExists()
        compose.onNodeWithText("What happened, where, and what was reported").assertExists()
        listOf("Water damage", "Heating / cooling", "Pest", "Appliance", "Structural", "Plumbing", "Electrical", "Other").forEach {
            compose.onNodeWithText(it).assertExists()
        }
        compose.onNodeWithText("Other").assert(SemanticsMatcher.expectValue(SemanticsProperties.Selected, true))
        compose.onNodeWithText("Attach photos").assertExists()
        compose.onNodeWithText("MoveMark dates the case and keeps its photos with the record.").assertExists()

        compose.onAllNodes(hasSetTextAction())[0].performTextInput("Leak under sink")
        compose.onNodeWithText("Heating / cooling").performScrollTo().performClick()
        compose.onNodeWithText("Heating / cooling").assert(SemanticsMatcher.expectValue(SemanticsProperties.Selected, true))
        compose.onNodeWithText("Save issue").performScrollTo().performClick()
        assertEquals(MaintenanceIssueDraft("Leak under sink", "Heating / cooling", ""), saved)
    }

    @Test
    fun newIssueFormShowsItsError() {
        compose.setContent {
            MaintenanceNewIssueForm(
                title = "", onTitle = {}, category = MaintenanceCategory.Default, onCategory = {},
                details = "", onDetails = {}, photos = emptyList(), onAttachPhotos = {},
                isSubmitting = false, errorMessage = "Enter an issue title.", onCancel = {}, onSave = {},
            )
        }
        compose.onNodeWithText("Enter an issue title.").assertExists()
    }
}
