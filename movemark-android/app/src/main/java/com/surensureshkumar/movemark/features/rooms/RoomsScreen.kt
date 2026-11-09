/**
 * @file The rental's rooms as proof coverage (iOS `RoomListView`): the record header (ROOMS · the rental · its
 *       address, move-in proof on the dark header), then the rooms block — the next room with the one capture
 *       action, every room with what it holds, and Add a room. Opened from Proof; system back returns there.
 * @domain rooms
 * @see [[RoomListView.swift]] [[MMSystem+Rental.swift]] — iOS reference
 */
package com.surensureshkumar.movemark.features.rooms

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.outlined.MeetingRoom
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMEmptyBlock
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMHeaderProofProgress
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLoadingBlock
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowChevron
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.mmLines
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.core.design.mmRoomGlyph
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.domain.RentalLocation
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.util.UUID

@Composable
fun RoomsScreen(
    onOpenRoom: (UUID) -> Unit,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    /** Every room documented: the record's next step is the report. */
    onOpenReports: () -> Unit = {},
    viewModel: RoomsViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val isAddingRoom by viewModel.isAddingRoom.collectAsState()
    val addRoomError by viewModel.addRoomError.collectAsState()
    var showAddRoomDialog by remember { mutableStateOf(false) }
    var newRoomName by remember { mutableStateOf("") }

    if (showAddRoomDialog) {
        AlertDialog(
            onDismissRequest = {
                showAddRoomDialog = false
                newRoomName = ""
                viewModel.clearAddRoomError()
            },
            containerColor = MMInk.Sheet,
            title = { Text("Add a room", color = MMInk.Text) },
            text = {
                Column {
                    OutlinedTextField(
                        value = newRoomName,
                        onValueChange = { newRoomName = it },
                        label = { Text("Room name") },
                        singleLine = true,
                    )
                    addRoomError?.let { msg ->
                        Spacer(Modifier.height(8.dp))
                        Text(msg, color = MMInk.Danger, fontSize = 13.sp)
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.addRoom(newRoomName) {
                            showAddRoomDialog = false
                            newRoomName = ""
                        }
                    },
                    enabled = newRoomName.isNotBlank() && !isAddingRoom,
                ) { Text(if (isAddingRoom) "Adding…" else "Add", color = MMInk.Text, fontWeight = FontWeight.SemiBold) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showAddRoomDialog = false
                    newRoomName = ""
                    viewModel.clearAddRoomError()
                }) { Text("Cancel", color = MMInk.Secondary) }
            },
        )
    }

    val p = property
    val rooms = p?.rooms.orEmpty()
    MMScreen(
        title = p?.title?.trim()?.ifEmpty { null } ?: "Rooms",
        eyebrow = "Rooms",
        lines = listOfNotNull(p?.let { addressLine(it) }),
        onBack = onBack,
        showsWordmark = true,
        modifier = modifier,
        trailing = {
            IconButton(onClick = { showAddRoomDialog = true }) {
                Icon(Icons.Filled.Add, contentDescription = "Add room", tint = Color.White)
            }
        },
        headerAccessory = if (rooms.isNotEmpty() && p != null) {
            { MMHeaderProofProgress(done = RoomProofMetrics.documentedCount(p), total = rooms.size) }
        } else {
            null
        },
    ) {
        when {
            loading && p == null -> MMLoadingBlock()
            p == null -> MMEmptyBlock(icon = Icons.Outlined.MeetingRoom, title = "No rooms loaded")
            rooms.isEmpty() -> MMEmptyBlock(
                icon = Icons.Outlined.MeetingRoom,
                title = "No rooms yet",
                message = "Add each room you'll document — start with the one you're standing in. Photos taken before you unpack become your move-in record.",
                actionTitle = "Add a room",
                onAction = { showAddRoomDialog = true },
            )
            else -> RentalRoomsBlock(
                property = p,
                onOpenRoom = onOpenRoom,
                onCompleteAction = onOpenReports,
                onAddRoom = { showAddRoomDialog = true },
            )
        }
    }
}

/** "88 Harbour St · Toronto, ON": the street leads only when the title is a nickname. Never a placeholder. */
private fun addressLine(p: PropertyRecord): String? {
    val street = p.addressLine1.trim().takeUnless {
        it.isEmpty() || it == "Address" || it.equals(p.title.trim(), ignoreCase = true) ||
            it.equals(RentalLocation.meaningful(p.city).orEmpty(), ignoreCase = true)
    }
    val place = RentalLocation.line(p.city, p.provinceState)
    return listOfNotNull(street, place.ifEmpty { null }).joinToString(" · ").ifEmpty { null }
}

/** The rooms as one object: the next room with the capture action on top, then every other room (iOS `MMRentalRoomsBlock`). */
@Composable
private fun RentalRoomsBlock(
    property: PropertyRecord,
    onOpenRoom: (UUID) -> Unit,
    onCompleteAction: () -> Unit,
    onAddRoom: () -> Unit,
) {
    val next = RoomProofMetrics.nextRoom(property)
    val others = property.rooms.filter { it.id != next?.id }
    val large = mmIsLargeFont()
    MMGroup {
        if (next != null) {
            Column(Modifier.padding(16.dp)) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .mmPressable(onClickLabel = "Open ${next.name}", onClick = { onOpenRoom(next.id) })
                        .semantics(mergeDescendants = true) {},
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text("Next room", style = mmFont(12.5f), color = MMInk.Secondary)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (!large) {
                            Icon(mmRoomGlyph(next.name), contentDescription = null, tint = MMInk.Text.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(next.name, style = mmFont(20f, FontWeight.SemiBold), color = MMInk.Text, maxLines = mmLines(1), overflow = TextOverflow.Ellipsis)
                    }
                    Text("No proof yet — photograph it before you unpack.", style = mmFont(13f), color = MMInk.Secondary)
                }
                Spacer(Modifier.height(14.dp))
                MMPrimaryButton(title = "Capture ${next.name}", icon = Icons.Filled.CameraAlt, onClick = { onOpenRoom(next.id) })
            }
        } else {
            val photos = RoomProofMetrics.totalPhotoCount(property)
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MMInk.Text, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Every room documented", style = mmFont(18f, FontWeight.SemiBold), color = MMInk.Text)
                }
                Text(
                    "${if (property.rooms.size == 1) "1 room" else "${property.rooms.size} rooms"} · ${if (photos == 1) "1 photo" else "$photos photos"} recorded",
                    style = mmFont(13f),
                    color = MMInk.Secondary,
                    modifier = Modifier.padding(start = if (large) 0.dp else 26.dp, top = 2.dp),
                )
                Spacer(Modifier.height(14.dp))
                MMPrimaryButton(title = "Generate move‑in report", icon = Icons.Filled.Description, onClick = onCompleteAction)
            }
        }
        others.forEach { room ->
            MMRowDivider(leading = if (large) 16.dp else 52.dp)
            RoomRow(room, large) { onOpenRoom(room.id) }
        }
        MMRowDivider(leading = if (large) 16.dp else 52.dp)
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .mmPressable(onClick = onAddRoom)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(20.dp).width(24.dp))
            Spacer(Modifier.width(12.dp))
            Text("Add a room", style = mmFont(15.5f), color = MMInk.Text)
        }
    }
    Spacer(Modifier.height(MMMetrics.Inset))
}

@Composable
private fun RoomRow(room: RoomRecord, large: Boolean, onClick: () -> Unit) {
    val photos = RoomProofMetrics.moveInPhotoCount(room)
    val issues = RoomProofMetrics.issueTagCount(room)
    val documented = RoomProofMetrics.isDocumented(room)
    val line = if (!documented) "Needs proof" else buildList {
        add("Recorded")
        add(if (photos == 1) "1 photo" else "$photos photos")
        if (issues > 0) add(if (issues == 1) "1 issue" else "$issues issues")
    }.joinToString(" · ")
    Row(
        Modifier
            .fillMaxWidth()
            .mmPressable(onClickLabel = "Open ${room.name}", onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .heightIn(min = MMMetrics.RowHeight)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (!large) {
            Icon(
                mmRoomGlyph(room.name),
                contentDescription = null,
                tint = MMInk.Text.copy(alpha = if (documented) 0.75f else 0.45f),
                modifier = Modifier.size(20.dp).width(24.dp),
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(room.name, style = mmFont(16f), color = MMInk.Text, maxLines = mmLines(2), overflow = TextOverflow.Ellipsis)
            Text(line, style = mmFont(13f), color = MMInk.Secondary, maxLines = mmLines(1))
        }
        if (documented) {
            Icon(
                Icons.Filled.CheckCircle,
                contentDescription = null,
                tint = MMInk.Text,
                modifier = Modifier
                    .size(19.dp)
                    .semantics { contentDescription = "Recorded" },
            )
        } else {
            Spacer(
                Modifier
                    .size(17.dp)
                    .border(1.5.dp, MMInk.Secondary.copy(alpha = 0.5f), CircleShape)
                    .semantics { contentDescription = "Needs proof" },
            )
        }
        MMRowChevron()
    }
}
