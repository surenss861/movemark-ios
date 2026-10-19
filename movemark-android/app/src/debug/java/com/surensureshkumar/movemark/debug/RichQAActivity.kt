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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.MMTheme
import com.surensureshkumar.movemark.core.design.components.MMRoomProgressCard
import com.surensureshkumar.movemark.core.design.components.MMRoomProofRow
import com.surensureshkumar.movemark.core.design.components.MMVaultProofHeroCard
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.data.models.EvidencePhoto
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.features.proof.EntryDetailsForm
import com.surensureshkumar.movemark.features.proof.EntryDraft
import com.surensureshkumar.movemark.features.proof.Kicker
import com.surensureshkumar.movemark.features.proof.PendingPhoto
import com.surensureshkumar.movemark.features.proof.RoomEvidenceBody
import com.surensureshkumar.movemark.features.proof.RoomEvidenceHero
import com.surensureshkumar.movemark.features.proof.RoomProofBottomSaveBar
import com.surensureshkumar.movemark.features.proof.RoomProofPhotoGrid
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
                if (screen.startsWith("room-")) {
                    RoomQAScreen(screen)
                    return@MMTheme
                }
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

/** Same fixtures and case names as iOS `MMRichQAGallery` RoomQAScreen; photos are drawn, not real. */
@Composable
private fun RoomQAScreen(screen: String) {
    val context = LocalContext.current
    fun entry(
        title: String, photos: Int, seed: Int, minutesAgo: Long,
        tags: List<String> = emptyList(), rating: Int = 4, notes: String = "",
    ) = EvidenceRecord(
        id = UUID.randomUUID(),
        title = title,
        notes = notes,
        photoCount = photos,
        photos = List(photos) { EvidencePhoto(UUID.randomUUID(), "qa-fixture/room-${seed + it}.jpg") },
        conditionRating = rating,
        createdAt = Instant.now().minusSeconds(minutesAgo * 60).toString(),
        issueTagCount = tags.size,
        issueTags = tags,
    )
    data class Fixture(
        val name: String,
        val moveIn: List<EvidenceRecord> = emptyList(),
        val moveOut: List<EvidenceRecord> = emptyList(),
        val phase: ProofPhase = ProofPhase.MoveIn,
        val pending: Int = 0,
    )
    val f = when (screen) {
        "room-one" -> Fixture("Primary Bedroom", listOf(entry("Primary Bedroom", 1, 0, 40)))
        "room-many" -> Fixture("Kitchen", listOf(
            entry("Counters and cabinets", 4, 1, 20),
            entry("Appliances", 3, 5, 60),
            entry("Kitchen", 2, 8, 90),
        ))
        "room-damage" -> Fixture("Living Room", listOf(
            entry("North wall", 3, 2, 15, listOf("Scratch", "Chipped paint"), 3,
                "Two scratches beside the window, about 20 cm long. Paint chipped at the baseboard corner."),
            entry("Floor by the balcony door", 2, 6, 50, listOf("Water damage"), 2,
                "Swollen laminate seam, already there at move-in."),
        ))
        "room-moveout" -> Fixture(
            "Kitchen",
            moveIn = listOf(entry("Kitchen", 4, 1, 60L * 24 * 300)),
            moveOut = listOf(entry("Kitchen at move-out", 3, 3, 10)),
            phase = ProofPhase.MoveOut,
        )
        "room-pending" -> Fixture("Living Room", pending = 3)
        "room-long" -> Fixture("Primary Bedroom Closet and Ensuite Bathroom", listOf(entry("Closet", 2, 4, 30, listOf("Stain"))))
        else -> Fixture("Balcony/Patio")
    }
    val entries = if (f.phase == ProofPhase.MoveOut) f.moveOut else f.moveIn
    val pending = remember(screen) { List(f.pending) { PendingPhoto(bytes = fixtureJpeg(it + 2)) } }
    var draft by remember { mutableStateOf(EntryDraft(conditionRating = 3, tags = setOf("Scratch"))) }
    val signUrl: suspend (String) -> String? = { path -> fixturePhotoUri(context, path.filter { it.isDigit() }.toIntOrNull() ?: 0) }

    MMBackground {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            contentWindowInsets = androidx.compose.foundation.layout.WindowInsets(0),
            bottomBar = {
                if (pending.isNotEmpty()) {
                    RoomProofBottomSaveBar(
                        saveButtonLabel = "Save proof", statusLine = "${pending.size} photos ready to save",
                        photoCount = pending.size, isBusy = false, isPartial = false, isFailed = false,
                        onSave = {}, onContinueWithSaved = {}, onRetry = {},
                        modifier = Modifier.navigationBarsPadding(),
                    )
                }
            },
        ) { padding ->
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(bottom = padding.calculateBottomPadding())
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 48.dp),
            ) {
                RoomEvidenceHero(
                    roomName = f.name, entries = entries, proofPhase = f.phase, signPhotoUrl = signUrl,
                    onBack = {}, onOpenPhoto = {}, hasPendingPhotos = pending.isNotEmpty(), isBusy = false,
                    onTakePhotos = {}, onChooseGallery = {},
                    compareLine = if (f.phase == ProofPhase.MoveOut && f.moveIn.isNotEmpty())
                        "MOVE-IN ${f.moveIn.sumOf { it.photoCount }} · MOVE-OUT ${f.moveOut.sumOf { it.photoCount }} PHOTOS" else null,
                )
                Column(Modifier.padding(horizontal = MMSpacing.ScreenHorizontal.dp)) {
                    if (entries.isNotEmpty()) {
                        RoomEvidenceBody(
                            entries = entries, proofPhase = f.phase, isBusy = false,
                            onEdit = {}, onAddPhotos = {}, onDelete = {}, onTakePhotos = {}, onChooseGallery = {},
                            modifier = Modifier.padding(top = 10.dp),
                        )
                    }
                    if (pending.isNotEmpty()) {
                        Spacer(Modifier.height(18.dp))
                        Kicker("NEW ENTRY", MMColors.TextMuted)
                        Spacer(Modifier.height(16.dp))
                        RoomProofPhotoGrid(photos = pending, reduceMotion = true)
                        Spacer(Modifier.height(16.dp))
                        EntryDetailsForm(draft = draft, onChange = { draft = it }, enabled = true)
                    }
                }
            }
        }
    }
}

/** Drawn stand-in for a room photo, varied by seed (same palettes as iOS). */
private fun fixtureJpeg(seed: Int): ByteArray {
    val palettes = listOf(
        AndroidColor.rgb(199, 184, 158) to AndroidColor.rgb(115, 84, 56),
        AndroidColor.rgb(219, 219, 212) to AndroidColor.rgb(140, 128, 112),
        AndroidColor.rgb(179, 194, 189) to AndroidColor.rgb(92, 77, 66),
        AndroidColor.rgb(232, 217, 194) to AndroidColor.rgb(158, 120, 84),
    )
    val (wall, floor) = palettes[seed % palettes.size]
    val bmp = Bitmap.createBitmap(1200, 1400, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val p = Paint()
    p.color = wall; c.drawRect(0f, 0f, 1200f, 1400f, p)
    p.color = floor; c.drawRect(0f, 960f, 1200f, 1400f, p)
    p.color = AndroidColor.rgb(247, 247, 247); c.drawRect(0f, 940f, 1200f, 962f, p)
    val x = 200f + (seed * 170) % 600
    p.color = AndroidColor.rgb(235, 242, 252); c.drawRect(x, 220f, x + 320f, 680f, p)
    val out = java.io.ByteArrayOutputStream()
    bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
    return out.toByteArray()
}

private fun fixturePhotoUri(context: Context, seed: Int): String {
    val file = File(context.cacheDir, "mm-qa-room-$seed.jpg")
    if (!file.exists()) file.writeBytes(fixtureJpeg(seed))
    return Uri.fromFile(file).toString()
}
