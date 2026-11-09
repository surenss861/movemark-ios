/**
 * @file Proof tab (iOS `ProofHomeView`): a quiet dark header carrying the rental and its move-in proof progress,
 *       then the light sheet — the next room with the one capture action, the evidence counts, the recent
 *       evidence strip, the rooms still to do, and the next actions. Evidence lives only inside its own clipped
 *       thumbnails, never as a header photo.
 * @domain vault
 * @see [[ProofHomeView.swift]] — iOS reference
 * @see [[VaultViewModel.kt]] — live data
 */
package com.surensureshkumar.movemark.features.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.ReportProblem
import androidx.compose.material.icons.outlined.TextSnippet
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMLoadingBlock
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRow
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMSectionTitle
import com.surensureshkumar.movemark.core.design.MMTag
import com.surensureshkumar.movemark.core.design.MMEyebrowStyle
import com.surensureshkumar.movemark.core.design.MMHeaderProofProgress
import com.surensureshkumar.movemark.core.design.MMWordmark
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.mmLines
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.core.design.mmPullUp
import com.surensureshkumar.movemark.core.design.mmRoomGlyph
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.VaultSummary
import com.surensureshkumar.movemark.domain.LifecycleNudge
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.domain.RentalLocation
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

@Composable
fun VaultScreen(
    onOpenRoom: (UUID) -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onOpenRoomPhase: (UUID, ProofPhase) -> Unit = { id, _ -> onOpenRoom(id) },
    onAddProperty: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    onOpenReports: () -> Unit = {},
    onOpenMaintenance: () -> Unit = {},
    onOpenDocuments: () -> Unit = {},
    /** The rental's rooms (iOS: the progress line and "View all" open the rental). */
    onOpenRooms: () -> Unit = {},
    modifier: Modifier = Modifier,
    scrollState: androidx.compose.foundation.ScrollState = rememberScrollState(),
    viewModel: VaultViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val properties by viewModel.properties.collectAsState()
    val summaries by viewModel.summaries.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val propertyCount by viewModel.propertyCount.collectAsState()
    val maintenanceLog by viewModel.maintenanceLog.collectAsState()
    val pendingRooms by viewModel.pendingRooms.collectAsState()
    val recent by viewModel.recent.collectAsState()

    val addRental = {
        if (!hasPro && propertyCount >= 1) onShowPaywall(PaywallReason.ExtraProperty) else onAddProperty()
    }

    MMLightSystemBars()
    val p = property
    if (p == null && !loading) {
        ProofHomeEmpty(errorMessage = error, onStart = onAddProperty, modifier = modifier)
        return
    }

    val otherRentals = properties.filter { p == null || it.id != p.id.toString() }
    Box(modifier.fillMaxSize().background(MMInk.Sheet)) {
        Column(Modifier.fillMaxSize().verticalScroll(scrollState)) {
            // Header: the rental and its proof state.
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(MMInk.Hero)
                    .statusBarsPadding()
                    .padding(horizontal = MMMetrics.Inset)
                    .padding(bottom = 26.dp + MMMetrics.SheetRadius),
            ) {
                Row(Modifier.fillMaxWidth().height(48.dp), verticalAlignment = Alignment.CenterVertically) {
                    MMWordmark()
                    Spacer(Modifier.weight(1f))
                    RentalMenu(
                        otherRentals = otherRentals,
                        summaries = summaries,
                        onAddRental = addRental,
                        onOpenRental = { viewModel.activateProperty(UUID.fromString(it)) },
                    )
                }
                if (!mmIsLargeFont()) {
                    Text("YOUR PROOF", style = MMEyebrowStyle, color = MMInk.HeroSecondary, modifier = Modifier.padding(top = 18.dp))
                }
                Text(
                    p?.title?.ifBlank { null } ?: "Your rental",
                    style = mmFont(27f, FontWeight.SemiBold),
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .semantics { heading() },
                )
                p?.let { RentalLocation.line(it.city, it.provinceState) }?.takeIf { it.isNotEmpty() }?.let {
                    Text(it, style = mmFont(14f), color = MMInk.HeroSecondary, maxLines = mmLines(1), modifier = Modifier.padding(top = 3.dp))
                }
                if (p != null) {
                    MMHeaderProofProgress(
                        done = RoomProofMetrics.documentedCount(p),
                        total = p.rooms.size,
                        showsChevron = true,
                        onClick = onOpenRooms,
                        modifier = Modifier.padding(top = 22.dp),
                    )
                }
            }

            // Sheet.
            Column(
                Modifier
                    .fillMaxWidth()
                    .mmPullUp(MMMetrics.SheetRadius)
                    .clip(RoundedCornerShape(topStart = MMMetrics.SheetRadius, topEnd = MMMetrics.SheetRadius))
                    .background(MMInk.Sheet)
                    .padding(horizontal = MMMetrics.Inset)
                    .padding(top = 20.dp),
            ) {
                // Photos still only on this phone (not uploaded yet): one quiet row that opens their room.
                if (pendingRooms.isNotEmpty()) {
                    MMPendingUploadsRow(
                        count = pendingRooms.sumOf { it.count },
                        failed = pendingRooms.any { it.failedCount > 0 },
                        onOpen = { viewModel.openPendingRoom(pendingRooms.first(), onOpenRoomPhase) },
                    )
                    Spacer(Modifier.height(12.dp))
                }
                error?.let {
                    MMNotice(it, tone = MMNoticeTone.Error)
                    Spacer(Modifier.height(14.dp))
                }
                if (p == null) {
                    MMLoadingBlock(message = "Loading your proof vault…")
                } else {
                    ProofSheet(
                        p = p,
                        properties = properties,
                        hasPro = hasPro,
                        openIssues = maintenanceLog.count { it.status != "resolved" },
                        recent = recent,
                        onOpenRoom = onOpenRoom,
                        onOpenRooms = onOpenRooms,
                        onOpenDocuments = onOpenDocuments,
                        onOpenMaintenance = onOpenMaintenance,
                        onOpenReports = onOpenReports,
                        onOpenMoveOutProof = onOpenMoveOutProof,
                        onShowPaywall = onShowPaywall,
                    )
                }
                Spacer(Modifier.height(MMMetrics.RootTabTail))
                Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
        }
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(MMInk.Hero))
    }
}

@Composable
private fun ProofSheet(
    p: com.surensureshkumar.movemark.data.models.PropertyRecord,
    properties: List<PropertyRow>,
    hasPro: Boolean,
    openIssues: Int,
    recent: List<RecentEvidence>,
    onOpenRoom: (UUID) -> Unit,
    onOpenRooms: () -> Unit,
    onOpenDocuments: () -> Unit,
    onOpenMaintenance: () -> Unit,
    onOpenReports: () -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
) {
    val documented = RoomProofMetrics.documentedCount(p)
    val total = p.rooms.size
    val next = RoomProofMetrics.nextRoom(p)
    val records = p.supportingRecordCount
    val exportReady = documented > 0 && (3 - records) <= 2
    val primaryTitle = when {
        documented == 0 -> "Start room proof"
        next != null -> "Capture ${next.name}"
        records < 3 -> "Add docs"
        openIssues > 0 -> "Continue move-in proof"
        else -> "Make your move-in report"
    }
    val onPrimary = {
        when {
            documented == 0 || next != null -> (next ?: p.rooms.firstOrNull())?.let { onOpenRoom(it.id) }
            records < 3 -> onOpenDocuments()
            openIssues > 0 -> onOpenMaintenance()
            else -> onOpenReports()
        }
        Unit
    }

    // The one primary action: the next room and its capture button, together.
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMMetrics.CardRadius))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius))
            .padding(horizontal = 18.dp, vertical = 14.dp),
    ) {
        if (next != null) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .mmPressable(onClickLabel = "Open ${next.name}", onClick = { onOpenRoom(next.id) })
                    .semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Text("Next room", style = mmFont(12f), color = MMInk.Secondary)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (!mmIsLargeFont()) {
                        Icon(mmRoomGlyph(next.name), contentDescription = null, tint = MMInk.Text.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(next.name, style = mmFont(20f, FontWeight.SemiBold), color = MMInk.Text, maxLines = mmLines(1), overflow = TextOverflow.Ellipsis)
                }
                if (!mmIsLargeFont()) Text("No proof yet", style = mmFont(13f), color = MMInk.Secondary)
            }
        } else if (total > 0) {
            Text("Move-in proof", style = mmFont(12f), color = MMInk.Secondary)
            Text("Every room documented", style = mmFont(20f, FontWeight.SemiBold), color = MMInk.Text)
        }
        Spacer(Modifier.height(12.dp))
        MMPrimaryButton(
            title = primaryTitle,
            icon = if (next != null || documented == 0) Icons.Filled.CameraAlt else Icons.Filled.Description,
            onClick = onPrimary,
            height = 44.dp,
        )
    }

    // The counts, subordinate to the proof state: one quiet line.
    Spacer(Modifier.height(16.dp))
    Row(Modifier.padding(horizontal = 4.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
        Metric(Icons.Outlined.CameraAlt, RoomProofMetrics.totalPhotoCount(p), "photo")
        Metric(Icons.Outlined.TextSnippet, records, "record")
        Metric(Icons.Outlined.ReportProblem, openIssues, "issue")
    }

    if (recent.isNotEmpty()) {
        Spacer(Modifier.height(30.dp))
        MMSectionTitle("Recent evidence", trailing = "View all", onTrailing = onOpenRooms)
        Spacer(Modifier.height(8.dp))
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val side = if (recent.size == 1) 128.dp else 104.dp
            recent.forEach { item -> EvidenceTile(item, side) { onOpenRoom(item.roomId) } }
        }
    }

    // Every room without proof (the next one included), as one row into the rental.
    val remaining = p.rooms.count { !RoomProofMetrics.isDocumented(it) }
    if (remaining > 1 || (remaining == 1 && next == null)) {
        Spacer(Modifier.height(28.dp))
        ListContainer {
            MMRow(
                title = if (remaining == 1) "1 room still needs proof" else "$remaining rooms still need proof",
                icon = Icons.Outlined.GridView,
                titleSize = 14.5f,
                onClick = onOpenRooms,
            )
        }
    }

    // Next actions: genuinely incomplete or timely work only.
    val row = properties.firstOrNull { it.id == p.id.toString() }
    val nudge = row?.let { LifecycleNudge.forProperty(it, p, openIssues) }?.takeUnless {
        it is LifecycleNudge.FinishRoomsBeforeUnpacking ||
            it is LifecycleNudge.AddLeaseAndDepositDocs ||
            it is LifecycleNudge.MidLeaseMaintenance
    }
    Spacer(Modifier.height(30.dp))
    MMSectionTitle("Next actions")
    Spacer(Modifier.height(12.dp))
    ListContainer {
        var first = true
        @Composable
        fun divider() {
            if (!first) MMRowDivider(leading = 52.dp)
            first = false
        }
        nudge?.let { n ->
            divider()
            MMRow(
                title = n.title,
                subtitle = n.reason,
                icon = Icons.Outlined.AutoAwesome,
                titleSize = 14.5f,
                onClick = {
                    when (n) {
                        is LifecycleNudge.MakeMoveInReport -> onOpenReports()
                        is LifecycleNudge.MoveOutProofReminder ->
                            if (hasPro) onOpenMoveOutProof() else onShowPaywall(PaywallReason.MoveOutProof)
                        is LifecycleNudge.FinishRoomsBeforeUnpacking -> (next ?: p.rooms.firstOrNull())?.let { onOpenRoom(it.id) }
                        is LifecycleNudge.AddLeaseAndDepositDocs -> onOpenDocuments()
                        is LifecycleNudge.MidLeaseMaintenance -> onOpenMaintenance()
                    }
                },
            )
        }
        // Each missing supporting record, as iOS lists them (all open the records screen). With all three on
        // file, one quiet row keeps the records reachable (iOS reaches them through the rental record).
        val missingRecords = VaultDocumentKind.priority.filterNot { VaultDocumentKind.isPresent(it, p.documentTypes) }
        if (missingRecords.isEmpty()) {
            divider()
            MMRow(title = "Records", subtitle = "Lease, deposit receipt and listing added", icon = Icons.Outlined.Description, titleSize = 14.5f, onClick = onOpenDocuments)
        }
        missingRecords.forEach { kind ->
            divider()
            MMRow(
                title = kind.title,
                subtitle = when (kind) {
                    VaultDocumentKind.Lease -> "Add your lease agreement"
                    VaultDocumentKind.DepositReceipt -> "Upload proof of deposit"
                    else -> "Save original listing"
                },
                icon = when (kind) {
                    VaultDocumentKind.Lease -> Icons.Outlined.Description
                    VaultDocumentKind.DepositReceipt -> Icons.Outlined.ReceiptLong
                    else -> Icons.Outlined.Image
                },
                titleSize = 14.5f,
                onClick = onOpenDocuments,
            )
        }
        divider()
        MMRow(
            title = "Maintenance issue",
            subtitle = when (openIssues) {
                0 -> "Report existing issues"
                1 -> "1 open issue"
                else -> "$openIssues open issues"
            },
            icon = Icons.Outlined.Build,
            titleSize = 14.5f,
            onClick = onOpenMaintenance,
        )
        divider()
        MMRow(
            title = "Move-out proof",
            subtitle = RoomProofMetrics.moveOutStatusLine(p),
            icon = Icons.Outlined.Inventory2,
            titleSize = 14.5f,
            trailing = if (hasPro) null else ({ MMTag("Pro") }),
            onClick = { if (hasPro) onOpenMoveOutProof() else onShowPaywall(PaywallReason.MoveOutProof) },
        )
        if (exportReady) {
            divider()
            MMRow(
                title = "Move-in report",
                subtitle = "Ready to make from saved proof",
                icon = Icons.Outlined.Description,
                titleSize = 14.5f,
                onClick = onOpenReports,
            )
        }
    }
}

@Composable
private fun Metric(icon: androidx.compose.ui.graphics.vector.ImageVector, count: Int, noun: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Icon(icon, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text("$count ${if (count == 1) noun else noun + "s"}", style = mmFont(13f), color = MMInk.Secondary)
    }
}

@Composable
private fun ListContainer(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMMetrics.CardRadius))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.CardRadius)),
        content = content,
    )
}

/** Fixed size and clipped to its own shape: a photo can never draw outside its tile. */
@Composable
private fun EvidenceTile(item: RecentEvidence, side: androidx.compose.ui.unit.Dp, onClick: () -> Unit) {
    val count = if (item.photoCount == 1) "1 photo" else "${item.photoCount} photos"
    Column(
        Modifier
            .width(side)
            .mmPressable(onClickLabel = "Open ${item.roomName}", onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = "${item.roomName}, $count" },
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Box(
            Modifier
                .size(side)
                .clip(RoundedCornerShape(12.dp))
                .background(MMInk.ThumbFill),
        ) {
            val request = rememberSignedImageRequest(item.url, item.path)
            if (request != null) {
                AsyncImage(model = request, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(item.roomName, style = mmFont(12.5f, FontWeight.Medium), color = MMInk.Text, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(tileCaption(item.capturedAt, count), style = mmFont(11.5f), color = MMInk.Secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

private fun tileCaption(raw: String?, count: String): String {
    val instant = raw?.let { runCatching { Instant.parse(it) }.getOrNull() } ?: return count
    val date = instant.atZone(ZoneId.systemDefault()).toLocalDate()
    val today = LocalDate.now()
    val day = when (date) {
        today -> "Today"
        today.minusDays(1) -> "Yesterday"
        else -> DateTimeFormatter.ofPattern("MMM d", Locale.getDefault()).format(date)
    }
    return "$day · $count"
}

/** Add a rental, or switch to another one (iOS header Menu). */
@Composable
private fun RentalMenu(
    otherRentals: List<PropertyRow>,
    summaries: Map<String, VaultSummary>,
    onAddRental: () -> Unit,
    onOpenRental: (String) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Box {
        Box(
            Modifier
                .size(48.dp)
                .mmPressable(
                    onClickLabel = if (otherRentals.isEmpty()) "Add a rental" else "Rentals",
                    onClick = { if (otherRentals.isEmpty()) onAddRental() else open = true },
                )
                .semantics { contentDescription = if (otherRentals.isEmpty()) "Add a rental" else "Rentals" },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (otherRentals.isEmpty()) Icons.Filled.Add else Icons.Filled.MoreHoriz,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text("Add a rental") },
                leadingIcon = { Icon(Icons.Filled.Add, contentDescription = null) },
                onClick = {
                    open = false
                    onAddRental()
                },
            )
            if (otherRentals.isNotEmpty()) {
                HorizontalDivider()
                Text(
                    "Your rentals",
                    style = mmFont(12f, FontWeight.Medium),
                    color = MMInk.Secondary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
                otherRentals.forEach { row ->
                    val summary = summaries[row.id.lowercase()]
                    val status = summary?.takeIf { it.roomsTotal > 0 }?.let { "${it.roomsDocumented} of ${it.roomsTotal} rooms documented" }
                        ?: RentalLocation.line(row.city, row.provinceState).ifEmpty { "Tap to switch" }
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(row.title)
                                Text(status, style = mmFont(12.5f), color = MMInk.Secondary)
                            }
                        },
                        onClick = {
                            open = false
                            onOpenRental(row.id)
                        },
                    )
                }
            }
        }
    }
}

/** No rental yet: the same light language, a quiet dark field, one lime action (iOS `ProofHomeEmptyView`). */
@Composable
private fun ProofHomeEmpty(errorMessage: String?, onStart: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().background(MMInk.Sheet)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(MMInk.Hero)
                    .statusBarsPadding()
                    .padding(horizontal = MMMetrics.Inset)
                    .heightIn(min = 130.dp),
            ) {
                Row(Modifier.height(48.dp), verticalAlignment = Alignment.CenterVertically) { MMWordmark() }
                Spacer(Modifier.height(60.dp))
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .mmPullUp(MMMetrics.SheetRadius)
                    .clip(RoundedCornerShape(topStart = MMMetrics.SheetRadius, topEnd = MMMetrics.SheetRadius))
                    .background(MMInk.Sheet)
                    .padding(20.dp)
                    .padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    "Prove what was already there.",
                    style = mmFont(30f, FontWeight.Bold),
                    color = MMInk.Text,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    "Add your rental, then photograph each room before you unpack. MoveMark keeps it as a dated record.",
                    style = mmFont(17f),
                    color = MMInk.Secondary,
                )
                errorMessage?.let { MMNotice(it, tone = MMNoticeTone.Error) }
                Spacer(Modifier.height(12.dp))
                MMPrimaryButton(title = "Add your rental", icon = Icons.Filled.Add, onClick = onStart)
                Spacer(Modifier.height(MMMetrics.RootTabTail))
                Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
        }
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(MMInk.Hero))
    }
}

/** The Proof home's quiet row while any room still has photos only on this phone (iOS `MMPendingUploadsRow`). */
@Composable
internal fun MMPendingUploadsRow(count: Int, failed: Boolean, onOpen: () -> Unit) {
    val title = if (count == 1) "1 photo not uploaded yet" else "$count photos not uploaded yet"
    ListContainer {
        MMRow(
            title = title,
            icon = if (failed) Icons.Filled.Error else Icons.Filled.PhoneAndroid,
            tint = if (failed) MMInk.Danger else MMInk.Text,
            titleSize = 14.5f,
            onClick = onOpen,
        )
    }
}
