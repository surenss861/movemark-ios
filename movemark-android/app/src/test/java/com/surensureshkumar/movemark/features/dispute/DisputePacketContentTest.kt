package com.surensureshkumar.movemark.features.dispute

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ExportVerificationStatus
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.remote.ExportJobStatus
import com.surensureshkumar.movemark.domain.DisputePacketModel
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/**
 * Native graphics, like the other full-screen Compose tests here: in Robolectric's legacy mode text has no real
 * metrics, and the rebuilt screen's header and notice row laid out with those fake sizes leave touch input missing
 * the controls (their semantics click works, a real tap at their centre doesn't). Real measurement fixes the taps.
 */
@RunWith(AndroidJUnit4::class)
@org.robolectric.annotation.GraphicsMode(org.robolectric.annotation.GraphicsMode.Mode.NATIVE)
class DisputePacketContentTest {
    @get:Rule val compose = createComposeRule()

    private val room = RoomRecord(
        UUID.randomUUID(), "Kitchen",
        listOf(EvidenceRecord(UUID.randomUUID(), "K", "", 1, listOf(EvidencePhoto(UUID.randomUUID(), "a.jpg")), 4, "2026-04-14T10:00:00Z")),
    )
    private val property = PropertyRecord(UUID.randomUUID(), "12 Elm St", "12 Elm St", "Toronto", "ON", listOf(room))

    // DisputePacketContent is the whole screen (MMScreen scrolls itself), so it isn't wrapped in a scroll here.
    private fun render(model: DisputePacketModel, events: MutableList<String>, error: String? = null) = compose.setContent {
        DisputePacketContent(
            model = model, question = "", amount = "", errorMessage = error, errorActionTitle = "Try again",
            isDownloading = false, sign = { null }, onQuestion = {}, onAmount = {},
            onToggleRoom = { events += "toggle" }, onOpenPhoto = { _, _ -> }, onCaptureMoveOut = {},
            onMissing = { events += "missing:$it" }, onGenerate = { events += "generate" },
            onView = { events += "view" }, onShare = { events += "share" }, onRetry = { events += "retry" },
        )
    }

    @Test
    fun headerNamesTheRentalOnceWithPurposeAndStatus() {
        val model = DisputePacketModel.make(property, emptyList(), emptyList(), emptySet(), hasPro = true)
        render(model, mutableListOf())
        compose.onNodeWithText("DISPUTE PACKET").assertIsDisplayed()
        compose.onNodeWithText("Build a record of the evidence related to this issue.").assertIsDisplayed()
        compose.onNodeWithText("Ready to generate").assertIsDisplayed()
        // The rental's name is the header title only; the sheet doesn't repeat it.
        compose.onAllNodesWithText(model.title).assertCountEquals(1)
    }

    @Test
    fun errorShowsAsANoticeWithItsAction() {
        val events = mutableListOf<String>()
        render(DisputePacketModel.make(property, emptyList(), emptyList(), emptySet(), hasPro = true), events, error = "Taking longer than usual.")
        compose.onNodeWithText("Taking longer than usual.").assertIsDisplayed()
        compose.onNodeWithText("Try again").performClick()
        assertEquals(listOf("retry"), events)
    }

    @Test
    fun readyPacketGeneratesAndRoomChipsToggle() {
        val events = mutableListOf<String>()
        render(DisputePacketModel.make(property, emptyList(), emptyList(), emptySet(), hasPro = false), events)
        compose.onNodeWithText("Ready to generate").assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Text))
        compose.onNodeWithText("Kitchen").performScrollTo()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Selected, false)).performClick()
        compose.onNodeWithText("Move-out proof not recorded").performScrollTo().performClick()
        compose.onNodeWithText("Generate evidence packet").performScrollTo().performClick()
        compose.onNodeWithText("The evidence packet is part of Pro.").performScrollTo()
        assertEquals(listOf("toggle", "missing:MoveOut", "generate"), events)
    }

    @Test
    fun generatedPacketOffersViewAndShare() {
        val events = mutableListOf<String>()
        val packet = ExportRow(UUID.randomUUID(), "dispute_packet", ExportJobStatus.Completed, ExportVerificationStatus.Ready, "2026-05-01T10:00:00Z", "f.pdf")
        render(DisputePacketModel.make(property, emptyList(), listOf(packet), emptySet(), hasPro = true), events)
        compose.onNodeWithText("Generated May 1").assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Text))
        compose.onNodeWithText("A new packet would include").performScrollTo()
        compose.onNodeWithText("View evidence packet").performScrollTo().performClick()
        compose.onNodeWithText("Share").performScrollTo().performClick()
        assertEquals(listOf("view", "share"), events)
    }
}
