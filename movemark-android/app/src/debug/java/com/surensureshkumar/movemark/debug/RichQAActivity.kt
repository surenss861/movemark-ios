/**
 * @file Debug-only fixture gallery for visual QA (vault-*, sprint-*, reports-*, room-*)
 * @domain design-system
 * @status stable
 * @see [[MMRichQAGallery.swift]] — iOS counterpart (same case names)
 * @see [[ROOM_EVIDENCE_RECORD]] — room-* cases verify this spec
 */
package com.surensureshkumar.movemark.debug

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.MMTheme
import com.surensureshkumar.movemark.core.design.components.MMRoomEvidencePlate
import com.surensureshkumar.movemark.core.design.components.MMRoomProgressCard
import com.surensureshkumar.movemark.core.design.components.MMRoomProofRow
import com.surensureshkumar.movemark.core.design.components.MMVaultProofHeroCard
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.features.reports.components.MMReportExportSection
import com.surensureshkumar.movemark.features.reports.components.MMReportPreviewHero
import java.io.File
import java.time.Instant
import java.util.UUID

/** Debug-only. Start with: adb shell am start -n com.surensureshkumar.movemark/.debug.RichQAActivity --es case vault-9 */
class RichQAActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val screen = intent.getStringExtra("case") ?: "vault-9"
        setContent {
            MMTheme {
                Column(
                    Modifier
                        .fillMaxSize()
                        .background(MMColors.AppBackground)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                        .padding(top = 28.dp, bottom = MMSpacing.TabScrollBottom.dp),
                ) {
                    QACase(screen)
                }
            }
        }
    }
}

private val sprintNames = listOf(
    "Kitchen", "Living Room", "Primary Bedroom", "Balcony/Patio", "Bathroom",
    "Hallway", "Laundry", "Storage", "Bedroom 2", "Office",
)

@Composable
private fun QACase(screen: String) {
    when (screen) {
        "vault-0" -> VaultCase(0, 0, "123 Main St", "Kitchen")
        "vault-1" -> VaultCase(1, 4, "123 Main St", "Living Room")
        "vault-9" -> VaultCase(9, 24, "123 Main St", "Primary Bedroom")
        "vault-10" -> VaultCase(10, 31, "123 Main St", null)
        "vault-long" -> VaultCase(9, 24, "1234 Westmoreland Avenue Northwest, Apartment 14B", "Balcony/Patio")
        "sprint-first" -> SprintCase(0, "Kitchen")
        "sprint-middle" -> SprintCase(2, "Primary Bedroom")
        "sprint-final" -> SprintCase(9, "Office")
        "reports-empty" -> ReportCase(ReportReadiness.NotReady, "Document a room to make your first report.", emptyList(), "Generate record")
        "reports-generating" -> ReportCase(ReportReadiness.Processing, "Generating your record.", listOf("9 rooms", "24 photos"), "Generating record", busy = true)
        "reports-ready" -> ReportCase(
            ReportReadiness.ReadyToShare,
            "Your move-in record is ready.",
            listOf("9 rooms", "24 photos", "2 issues"),
            "View / Share",
            generatedLine = "Generated Sep 28 · 6:34 PM",
            recordId = "MM-RP-4C82",
        )
        "reports-failed" -> ReportCase(ReportReadiness.Failed, "The report didn’t finish.", listOf("9 rooms", "24 photos"), "Try again")
        "reports-pro" -> ProCase()
        "room-photo" -> RoomPlateCase("Primary Bedroom", moveIn = 4, moveOut = 0, issues = 1, phase = ProofPhase.MoveIn)
        "room-empty" -> RoomPlateCase("Balcony/Patio", moveIn = 0, moveOut = 0, issues = 0, phase = ProofPhase.MoveIn)
        "room-moveout" -> RoomPlateCase("Kitchen", moveIn = 4, moveOut = 3, issues = 0, phase = ProofPhase.MoveOut)
        else -> VaultCase(9, 24, "123 Main St", "Primary Bedroom")
    }
}

@Composable
private fun VaultCase(documented: Int, photos: Int, address: String, next: String?) {
    MMVaultProofHeroCard(
        propertyName = address,
        location = "Toronto, ON",
        phaseLabel = "Move-in",
        progressLine = "$documented of 10 rooms documented",
        nextLine = next?.let { "Next: $it" } ?: "All rooms documented",
        progress = documented / 10f,
        primaryTitle = next?.let { "Capture $it" } ?: "Review your rooms",
        onPrimary = {},
        reduceMotion = true,
        documentedCount = documented,
        totalRooms = 10,
        photoCount = photos,
        recordCount = if (photos > 0) 3 else 0,
        issueCount = if (documented in 1..9) 2 else 0,
        lastProofLine = if (photos > 0) "Sep 28 · 6:34 PM" else null,
    )
}

@Composable
private fun SprintCase(doneThrough: Int, current: String) {
    MMRoomProgressCard(
        headline = "$doneThrough of 10 rooms documented",
        nextLine = "Next: $current",
        progress = doneThrough / 10f,
        primaryTitle = "Capture $current",
        onPrimary = {},
        reduceMotion = true,
        documentedCount = doneThrough,
        totalCount = 10,
    )
    Spacer(Modifier.height(16.dp))
    sprintNames.forEachIndexed { index, name ->
        MMRoomProofRow(
            room = qaRoom(name, photos = if (index < doneThrough) 4 else 0),
            index = index + 1,
            isNext = name == current,
            onClick = {},
        )
    }
}

@Composable
private fun ReportCase(
    readiness: ReportReadiness,
    headline: String,
    chips: List<String>,
    action: String,
    busy: Boolean = false,
    generatedLine: String? = null,
    recordId: String? = null,
) {
    MMReportPreviewHero(
        readiness = readiness,
        metricsLine = chips.joinToString(" · ").ifBlank { null },
        headline = headline,
        footnote = headline,
        proofChips = chips,
        primaryTitle = action,
        primaryEnabled = !busy,
        primaryLoading = busy,
        onPrimary = {},
        appeared = true,
        reduceMotion = true,
        generatedLine = generatedLine,
        recordId = recordId,
    )
}

@Composable
private fun ProCase() {
    MMReportPreviewHero(
        readiness = ReportReadiness.ReadyToShare,
        metricsLine = "9 rooms · 24 photos",
        headline = "Your move-in record is ready.",
        footnote = null,
        proofChips = listOf("9 rooms", "24 photos"),
        primaryTitle = "View / Share",
        primaryEnabled = true,
        primaryLoading = false,
        onPrimary = {},
        appeared = true,
        reduceMotion = true,
    )
    Spacer(Modifier.height(16.dp))
    MMReportExportSection(
        sectionTitle = "Move-out report",
        sectionSubtitle = "Re-capture the same rooms when you leave.",
        statusLine = "Ready to share",
        statusColor = MMColors.Primary,
        metricsLine = null,
        footnote = null,
        primaryTitle = "Upgrade to Pro",
        primaryEnabled = true,
        primaryLoading = false,
        onPrimary = {},
        appeared = true,
        reduceMotion = true,
        isProLocked = true,
    )
}

private fun qaRoom(name: String, photos: Int): RoomRecord {
    val evidence = if (photos == 0) {
        emptyList()
    } else {
        listOf(EvidenceRecord(id = UUID.randomUUID(), title = name, notes = "", photoCount = photos))
    }
    return RoomRecord(id = UUID.randomUUID(), name = name, moveInEvidence = evidence)
}

/** Same fixtures as iOS `MMRichQAGallery` room cases; the photo is drawn, not a real one. */
@Composable
private fun RoomPlateCase(name: String, moveIn: Int, moveOut: Int, issues: Int, phase: ProofPhase) {
    val context = LocalContext.current
    fun entries(count: Int, minutesAgo: Long, tags: Int) = if (count == 0) emptyList() else listOf(
        EvidenceRecord(
            id = UUID.randomUUID(),
            title = name,
            notes = "",
            photoCount = count,
            photos = List(count) { EvidencePhoto(UUID.randomUUID(), "qa-fixture/room-plate.jpg") },
            conditionRating = 4,
            createdAt = Instant.now().minusSeconds(minutesAgo * 60).toString(),
            issueTagCount = tags,
        ),
    )
    val room = RoomRecord(
        id = UUID.randomUUID(),
        name = name,
        moveInEvidence = entries(moveIn, 90, issues),
        moveOutEvidence = entries(moveOut, 5, 0),
    )
    MMRoomEvidencePlate(
        roomName = name,
        room = room,
        proofPhase = phase,
        shotPrompts = listOf(
            "Take a wide room photo",
            "Photograph walls and baseboards",
            "Photograph floors",
            "Photograph windows / blinds",
        ),
        signPhotoUrl = { fixturePhotoUri(context) },
    )
}

/** Warm wall, floor and window light, written once to the cache dir. */
private fun fixturePhotoUri(context: Context): String {
    val file = File(context.cacheDir, "mm-qa-room-plate.jpg")
    if (!file.exists()) {
        val bmp = Bitmap.createBitmap(1200, 900, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint()
        p.color = AndroidColor.rgb(199, 184, 158); c.drawRect(0f, 0f, 1200f, 900f, p)
        p.color = AndroidColor.rgb(115, 84, 56); c.drawRect(0f, 620f, 1200f, 900f, p)
        p.color = AndroidColor.rgb(237, 242, 250); c.drawRect(760f, 120f, 1060f, 500f, p)
        p.color = AndroidColor.rgb(242, 242, 242); c.drawRect(0f, 600f, 1200f, 624f, p)
        file.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 85, it) }
    }
    return Uri.fromFile(file).toString()
}
