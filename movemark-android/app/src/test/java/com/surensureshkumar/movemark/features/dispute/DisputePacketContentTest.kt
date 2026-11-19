package com.surensureshkumar.movemark.features.dispute

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
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

@RunWith(AndroidJUnit4::class)
class DisputePacketContentTest {
    @get:Rule val compose = createComposeRule()

    private val room = RoomRecord(
        UUID.randomUUID(), "Kitchen",
        listOf(EvidenceRecord(UUID.randomUUID(), "K", "", 1, listOf(EvidencePhoto(UUID.randomUUID(), "a.jpg")), 4, "2026-04-14T10:00:00Z")),
    )
    private val property = PropertyRecord(UUID.randomUUID(), "12 Elm St", "12 Elm St", "Toronto", "ON", listOf(room))

    private fun render(model: DisputePacketModel, events: MutableList<String>) = compose.setContent {
        Column(Modifier.verticalScroll(rememberScrollState())) {
            DisputePacketContent(
                model = model, question = "", amount = "", errorMessage = null, errorActionTitle = "Try again",
                isDownloading = false, sign = { null }, onQuestion = {}, onAmount = {},
                onToggleRoom = { events += "toggle" }, onOpenPhoto = { _, _ -> }, onCaptureMoveOut = {},
                onMissing = { events += "missing:$it" }, onGenerate = { events += "generate" },
                onView = { events += "view" }, onShare = { events += "share" }, onRetry = {},
            )
        }
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
