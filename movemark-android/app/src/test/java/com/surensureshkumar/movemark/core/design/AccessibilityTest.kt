package com.surensureshkumar.movemark.core.design

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.core.design.components.MMSettingsRow
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.MoveOutComparison
import com.surensureshkumar.movemark.features.moveout.ChecklistItemRow
import com.surensureshkumar.movemark.features.moveout.MoveOutMissingRow
import com.surensureshkumar.movemark.features.proof.PendingPhoto
import com.surensureshkumar.movemark.features.proof.RoomProofPhotoGrid
import com.surensureshkumar.movemark.features.vault.MMPendingUploadsRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.GraphicsMode
import java.util.UUID

/** TalkBack labels, 48 dp touch targets and 200% font behaviour, checked on the JVM (Robolectric). */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AccessibilityTest {
    @get:Rule val compose = createComposeRule()

    private fun at(fontScale: Float, content: @Composable () -> Unit) = compose.setContent {
        CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale)) {
            Column(Modifier.verticalScroll(rememberScrollState())) { content() }
        }
    }

    private val missing = MoveOutComparison.make(
        RoomRecord(UUID.randomUUID(), "Bedroom", listOf(EvidenceRecord(UUID.randomUUID(), "B", "", 1, createdAt = "2026-04-14T10:00:00Z"))),
    )

    @Test
    fun everyTappableElementHasA48dpTarget() {
        at(1f) {
            MMSettingsRow(title = "Sign out", onClick = {})
            ChecklistItemRow("Keys returned", done = false) {}
            MoveOutMissingRow(missing) {}
            MMPendingUploadsRow(count = 2, failed = true) {}
            RoomProofPhotoGrid(photos = listOf(PendingPhoto(id = "a", bytes = ByteArray(0))), onRemove = {})
        }
        val minPx = with(compose.density) { 48.dp.toPx() } - 0.5f
        val nodes = compose.onAllNodes(hasClickAction()).fetchSemanticsNodes()
        assertTrue(nodes.size >= 5)
        nodes.forEach { node ->
            val label = node.config.getOrNull(SemanticsProperties.ContentDescription) ?: node.config.getOrNull(SemanticsProperties.Text)
            assertTrue("$label: ${node.touchBoundsInRoot.height}px tall", node.touchBoundsInRoot.height >= minPx)
            assertTrue("$label: ${node.touchBoundsInRoot.width}px wide", node.touchBoundsInRoot.width >= minPx)
        }
    }

    @Test
    fun unsavedPhotosAreLabelledForTalkBack() {
        at(1f) { RoomProofPhotoGrid(photos = listOf(PendingPhoto(id = "a", bytes = ByteArray(0)), PendingPhoto(id = "b", bytes = ByteArray(0))), onRemove = {}) }
        compose.onNodeWithContentDescription("Remove photo 1").assertExists()
        compose.onNodeWithContentDescription("Remove photo 2").assertExists()
    }

    @Test
    fun singleLineLabelsWrapAt200PercentInsteadOfTruncating() {
        val long = "A rental name long enough that it cannot fit on one line"
        at(2f) { Text(long, maxLines = mmLines(), modifier = Modifier.width(120.dp)) }
        val layout = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
        compose.onNodeWithText(long).fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult].action!!(layout)
        assertTrue(layout.single().lineCount > 1)
        assertTrue(!layout.single().hasVisualOverflow)
    }

    @Test
    fun normalFontKeepsOneLine() {
        var lines = 0
        at(1f) { lines = mmLines() }
        assertEquals(1, lines)
    }
}
