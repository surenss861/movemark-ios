/**
 * @file Room body — condition, damage noted, saved entries (edit / add photos / delete), add more,
 *       plus the entry-details form shared by "New entry" and the edit sheet
 * @domain proof-capture
 * @status wip
 * @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4 composition)
 * @see [[RoomEvidenceBody.swift]] — iOS reference implementation
 */
package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.AddAPhoto
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.ui.text.style.TextAlign
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.domain.ProofPhase

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RoomEvidenceBody(
    entries: List<EvidenceRecord>,
    proofPhase: ProofPhase,
    isBusy: Boolean,
    onEdit: (EvidenceRecord) -> Unit,
    onAddPhotos: (EvidenceRecord) -> Unit,
    onDelete: (EvidenceRecord) -> Unit,
    modifier: Modifier = Modifier,
    /** Entries the server holds for this room and stage (loaded + not yet loaded). */
    totalEntries: Int = entries.size,
    hasOlderEntries: Boolean = false,
    isLoadingOlder: Boolean = false,
    onLoadOlder: () -> Unit = {},
    onShowAllPhotos: (EvidenceRecord) -> Unit = {},
) {
    val ordered = entries.sortedByDescending { it.createdAt.orEmpty() }
    val latest = ordered.firstOrNull()
    val damage = ordered.flatMap { it.issueTags }.distinct()
    val notes = ordered.mapNotNull { e -> e.notes.trim().takeIf { it.isNotEmpty() }?.let { e.title to it } }

    Column(modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        if (latest != null || damage.isNotEmpty() || notes.isNotEmpty()) {
            // Summary card: condition, then damage and notes.
            EvidenceCard {
                if (latest != null) ConditionRow(latest.conditionRating)
                if (damage.isNotEmpty() || notes.isNotEmpty()) {
                    if (latest != null) Hairline()
                    Column(Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Kicker(if (damage.isEmpty()) "NOTES" else "DAMAGE NOTED", MMInk.Secondary)
                        if (damage.isNotEmpty()) {
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                damage.forEach { DamagePill(it) }
                            }
                        }
                        notes.forEach { (title, text) ->
                            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                if (notes.size > 1) {
                                    Text(title, color = MMInk.Text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                                }
                                Text(text, color = MMInk.Secondary, fontSize = 16.sp, lineHeight = 22.sp)
                            }
                        }
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Kicker(if (proofPhase == ProofPhase.MoveOut) "MOVE-OUT ENTRIES" else "ENTRIES", MMInk.Secondary)
                Spacer(Modifier.weight(1f))
                Text("$totalEntries", fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMInk.Secondary)
            }
            EvidenceCard {
                ordered.forEachIndexed { index, entry ->
                    if (index > 0) Hairline()
                    EntryRow(entry, isBusy, onEdit, onAddPhotos, onDelete, onShowAllPhotos)
                }
                if (hasOlderEntries) {
                    Hairline()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .clickable(enabled = !isLoadingOlder && !isBusy, role = Role.Button, onClick = onLoadOlder),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        if (isLoadingOlder) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = MMInk.Lime)
                        Text(
                            if (isLoadingOlder) "Loading older entries…" else "Show older entries (${totalEntries - ordered.size} more)",
                            color = MMInk.Text,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }
        // Adding evidence lives on the hero ("Add evidence"), so the body ends with the record.
    }
}

/** A primary card on the light page: white, subtle grey hairline, card radius. */
@Composable
private fun EvidenceCard(content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(MMMetrics.CardRadius)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, shape)
            .padding(horizontal = 16.dp),
        content = content,
    )
}

@Composable
private fun ConditionRow(rating: Int?) {
    val value = rating ?: 0
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Condition ${conditionLabel(rating)}, $value of 5" },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Kicker("CONDITION", MMInk.Secondary)
        Spacer(Modifier.width(12.dp))
        Text(
            conditionLabel(rating),
            color = MMInk.Text,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            (1..5).forEach { step ->
                Box(
                    Modifier
                        .width(10.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(50))
                        .background(if (step <= value) MMInk.Text else MMInk.Track),
                )
            }
        }
    }
}

@Composable
private fun DamagePill(tag: String) {
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(MMColors.SemanticWarning.copy(alpha = 0.14f))
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.size(6.dp).clip(CircleShape).background(MMColors.SemanticWarning))
        Text(tag, color = MMInk.Text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun EntryRow(
    entry: EvidenceRecord,
    isBusy: Boolean,
    onEdit: (EvidenceRecord) -> Unit,
    onAddPhotos: (EvidenceRecord) -> Unit,
    onDelete: (EvidenceRecord) -> Unit,
    onShowAllPhotos: (EvidenceRecord) -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // Wraps at large font scales rather than truncating.
            Text(entry.title, color = MMInk.Text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            recordedLabel(entry.createdAt)?.let {
                Text(it, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMInk.Secondary)
            }
            Text(entrySummary(entry), color = MMInk.Secondary, fontSize = 13.sp)
        }
        Box {
            IconButton(onClick = { menuOpen = true }, enabled = !isBusy) {
                Icon(Icons.Filled.MoreVert, contentDescription = "Actions for ${entry.title}", tint = MMInk.Secondary)
            }
            // White native-style menu (the Material scheme is light); the destructive action sits below a divider.
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text("Edit details", color = MMInk.Text) },
                    leadingIcon = { Icon(Icons.Outlined.Edit, contentDescription = null, tint = MMInk.Text) },
                    onClick = { menuOpen = false; onEdit(entry) },
                )
                DropdownMenuItem(
                    text = { Text("Add photos", color = MMInk.Text) },
                    leadingIcon = { Icon(Icons.Outlined.AddAPhoto, contentDescription = null, tint = MMInk.Text) },
                    onClick = { menuOpen = false; onAddPhotos(entry) },
                )
                if (entry.hasUnloadedPhotos) {
                    DropdownMenuItem(
                        text = { Text("Show all ${entry.photoCount} photos", color = MMInk.Text) },
                        leadingIcon = { Icon(Icons.Outlined.PhotoLibrary, contentDescription = null, tint = MMInk.Text) },
                        onClick = { menuOpen = false; onShowAllPhotos(entry) },
                    )
                }
                HorizontalDivider(Modifier.padding(vertical = 4.dp), thickness = 0.75.dp, color = MMInk.Separator)
                DropdownMenuItem(
                    text = { Text("Delete entry", color = MMInk.Danger) },
                    leadingIcon = { Icon(Icons.Outlined.Delete, contentDescription = null, tint = MMInk.Danger) },
                    onClick = { menuOpen = false; onDelete(entry) },
                )
            }
        }
    }
}

private fun entrySummary(entry: EvidenceRecord): String = buildList {
    add(if (entry.photoCount == 1) "1 photo" else "${entry.photoCount} photos")
    add(conditionLabel(entry.conditionRating))
    if (entry.issueTags.isNotEmpty()) add(if (entry.issueTags.size == 1) "1 issue" else "${entry.issueTags.size} issues")
}.joinToString(" · ")

@Composable
private fun Hairline() {
    HorizontalDivider(thickness = 0.75.dp, color = MMInk.Separator)
}

/** Title, condition, issue tags, notes — the same fields and order as the iOS capture form. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EntryDetailsForm(
    draft: EntryDraft,
    onChange: (EntryDraft) -> Unit,
    enabled: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Details", color = MMInk.Text, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = draft.title,
            onValueChange = { onChange(draft.copy(title = it)) },
            label = { Text("Entry title") },
            placeholder = { Text("e.g. North wall") },
            singleLine = true,
            enabled = enabled,
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Kicker("CONDITION", MMInk.Secondary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                RoomConditionLabels.forEach { (rating, label) ->
                    SelectChip(label, selected = draft.conditionRating == rating, enabled = enabled) {
                        onChange(draft.copy(conditionRating = rating))
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Kicker("ISSUE TAGS", MMInk.Secondary)
                Spacer(Modifier.weight(1f))
                Text(
                    if (draft.tags.isEmpty()) "Optional" else "${draft.tags.size} selected",
                    color = MMInk.Secondary,
                    fontSize = 12.sp,
                )
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                RoomIssueTags.forEach { tag ->
                    val on = tag in draft.tags
                    SelectChip(tag, selected = on, enabled = enabled, attention = true) {
                        onChange(draft.copy(tags = if (on) draft.tags - tag else draft.tags + tag))
                    }
                }
            }
        }

        OutlinedTextField(
            value = draft.notes,
            onValueChange = { onChange(draft.copy(notes = it)) },
            label = { Text("Notes") },
            placeholder = { Text("What you saw, and where") },
            minLines = 2,
            enabled = enabled,
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun SelectChip(text: String, selected: Boolean, enabled: Boolean, attention: Boolean = false, onClick: () -> Unit) {
    val shape = RoundedCornerShape(50)
    // Lime is reserved for primary buttons and progress: a selected chip is ink-outlined (amber for issue tags).
    val selectedFill = if (attention) MMColors.SemanticWarning.copy(alpha = 0.12f) else MMInk.Field
    val selectedStroke = if (attention) MMColors.SemanticWarning.copy(alpha = 0.6f) else MMInk.Text
    Text(
        text,
        color = if (selected) MMInk.Text else MMInk.Secondary,
        fontSize = 14.sp,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        modifier = Modifier
            .heightIn(min = 36.dp)
            .clip(shape)
            .background(if (selected) selectedFill else MMInk.Card)
            .border(if (selected) 1.dp else 0.75.dp, if (selected) selectedStroke else MMInk.CardStroke, shape)
            .clickable(enabled = enabled, role = Role.Checkbox, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 13.dp, vertical = 9.dp),
    )
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = MMInk.Text,
    unfocusedTextColor = MMInk.Text,
    focusedBorderColor = MMInk.Text,
    unfocusedBorderColor = MMInk.CardStroke,
    focusedLabelColor = MMInk.Text,
    unfocusedLabelColor = MMInk.Secondary,
    cursorColor = MMInk.Text,
    focusedPlaceholderColor = MMInk.Secondary,
    unfocusedPlaceholderColor = MMInk.Secondary,
    focusedContainerColor = MMInk.Card,
    unfocusedContainerColor = MMInk.Card,
    disabledContainerColor = MMInk.Field,
)
