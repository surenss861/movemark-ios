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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
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
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ordered = entries.sortedByDescending { it.createdAt.orEmpty() }
    val latest = ordered.firstOrNull()
    val damage = ordered.flatMap { it.issueTags }.distinct()
    val notes = ordered.mapNotNull { e -> e.notes.trim().takeIf { it.isNotEmpty() }?.let { e.title to it } }

    Column(modifier.fillMaxWidth()) {
        if (latest != null) {
            ConditionRow(latest.conditionRating)
            Hairline()
        }

        if (damage.isNotEmpty() || notes.isNotEmpty()) {
            Column(Modifier.padding(vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Kicker(if (damage.isEmpty()) "NOTES" else "DAMAGE NOTED", MMColors.TextMuted)
                if (damage.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        damage.forEach { DamagePill(it) }
                    }
                }
                notes.forEach { (title, text) ->
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        if (notes.size > 1) {
                            Text(title, color = MMColors.TextMuted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Text(text, color = MMColors.TextSecondary, fontSize = 16.sp, lineHeight = 22.sp)
                    }
                }
            }
            Hairline()
        }

        Column(Modifier.padding(vertical = 18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Kicker(if (proofPhase == ProofPhase.MoveOut) "MOVE-OUT ENTRIES" else "ENTRIES", MMColors.TextMuted)
                Spacer(Modifier.weight(1f))
                Text("${ordered.size}", fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMColors.TextMuted)
            }
            Spacer(Modifier.height(4.dp))
            ordered.forEachIndexed { index, entry ->
                if (index > 0) HorizontalDivider(thickness = 0.5.dp, color = MMColors.CardStroke)
                EntryRow(entry, isBusy, onEdit, onAddPhotos, onDelete)
            }
        }
        Hairline()

        Column(Modifier.padding(vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Kicker("ADD MORE PROOF", MMColors.TextMuted)
            // Secondary on purpose: the room is documented, so green is reserved for saving.
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MMButton("Take photos", onTakePhotos, Modifier.weight(1f), style = MMButtonStyle.Secondary, enabled = !isBusy)
                MMButton("Gallery", onChooseGallery, Modifier.weight(1f), style = MMButtonStyle.Secondary, enabled = !isBusy)
            }
        }
    }
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
        Kicker("CONDITION", MMColors.TextMuted)
        Spacer(Modifier.weight(1f))
        Text(conditionLabel(rating), color = MMColors.TextPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.width(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            (1..5).forEach { step ->
                Box(
                    Modifier
                        .width(10.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(50))
                        .background(if (step <= value) MMColors.TextPrimary.copy(alpha = 0.85f) else MMColors.TextMuted.copy(alpha = 0.3f)),
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
        Text(tag, color = MMColors.TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun EntryRow(
    entry: EvidenceRecord,
    isBusy: Boolean,
    onEdit: (EvidenceRecord) -> Unit,
    onAddPhotos: (EvidenceRecord) -> Unit,
    onDelete: (EvidenceRecord) -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(entry.title, color = MMColors.TextPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
            recordedLabel(entry.createdAt)?.let {
                Text(it, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = MMColors.TextMuted)
            }
            Text(entrySummary(entry), color = MMColors.TextSecondary, fontSize = 13.sp)
        }
        Box {
            IconButton(onClick = { menuOpen = true }, enabled = !isBusy) {
                Icon(Icons.Filled.MoreVert, contentDescription = "Actions for ${entry.title}", tint = MMColors.TextSecondary)
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text("Edit details") },
                    leadingIcon = { Icon(Icons.Outlined.Edit, contentDescription = null) },
                    onClick = { menuOpen = false; onEdit(entry) },
                )
                DropdownMenuItem(
                    text = { Text("Add photos") },
                    leadingIcon = { Icon(Icons.Outlined.AddAPhoto, contentDescription = null) },
                    onClick = { menuOpen = false; onAddPhotos(entry) },
                )
                HorizontalDivider()
                DropdownMenuItem(
                    text = { Text("Delete entry", color = MMColors.SemanticDanger) },
                    leadingIcon = { Icon(Icons.Outlined.Delete, contentDescription = null, tint = MMColors.SemanticDanger) },
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
    HorizontalDivider(thickness = 0.5.dp, color = MMColors.CardStroke)
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
        Text("Details", color = MMColors.TextPrimary, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = draft.title,
            onValueChange = { onChange(draft.copy(title = it)) },
            label = { Text("Entry title") },
            placeholder = { Text("North wall paint wear") },
            singleLine = true,
            enabled = enabled,
            colors = fieldColors(),
            modifier = Modifier.fillMaxWidth(),
        )

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Kicker("CONDITION", MMColors.TextMuted)
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
                Kicker("ISSUE TAGS", MMColors.TextMuted)
                Spacer(Modifier.weight(1f))
                Text(
                    if (draft.tags.isEmpty()) "Optional" else "${draft.tags.size} selected",
                    color = MMColors.TextMuted,
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
            placeholder = { Text("What matters, where it is, what it looked like") },
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
    val selectedFill = if (attention) MMColors.SemanticWarning.copy(alpha = 0.18f) else MMColors.Primary.copy(alpha = 0.18f)
    val selectedStroke = if (attention) MMColors.SemanticWarning.copy(alpha = 0.55f) else MMColors.Primary.copy(alpha = 0.55f)
    Text(
        text,
        color = if (selected) MMColors.TextPrimary else MMColors.TextSecondary,
        fontSize = 14.sp,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        modifier = Modifier
            .heightIn(min = 36.dp)
            .clip(shape)
            .background(if (selected) selectedFill else MMColors.CardRaised.copy(alpha = 0.5f))
            .border(1.dp, if (selected) selectedStroke else Color.White.copy(alpha = 0.06f), shape)
            .clickable(enabled = enabled, role = Role.Checkbox, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 13.dp, vertical = 9.dp),
    )
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = MMColors.TextPrimary,
    unfocusedTextColor = MMColors.TextPrimary,
    focusedBorderColor = MMColors.Primary,
    unfocusedBorderColor = MMColors.CardStroke,
    focusedLabelColor = MMColors.Primary,
    unfocusedLabelColor = MMColors.TextMuted,
    cursorColor = MMColors.Primary,
    focusedPlaceholderColor = MMColors.TextMuted,
    unfocusedPlaceholderColor = MMColors.TextMuted,
)
