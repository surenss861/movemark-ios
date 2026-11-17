package com.surensureshkumar.movemark.features.maintenance

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest

/*
 * The maintenance case-file vocabulary (iOS `MMSystem+Maintenance.swift`): the calm status mark, the log's case
 * row, a case chronology row and the small captions. A documented case with a chronology — never a ticket.
 */

/** A signed thumbnail for a case (the log row / strip); [path] keys Coil's cache so a re-signed URL still hits. */
data class MaintenanceThumb(val url: String, val path: String)

/** iOS `MMCaseStatusMark`: a hollow ring while open or in follow-up, a lime dot once resolved. Never red, never a pill. */
@Composable
internal fun MaintenanceStatusMark(status: MaintenanceCaseStatus, modifier: Modifier = Modifier, onDark: Boolean = false) {
    Row(
        modifier.clearAndSetSemantics { contentDescription = "Status: ${status.label}" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (status.isResolved) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(MMInk.LimeMark))
        } else {
            Box(
                Modifier
                    .size(8.dp)
                    .border(1.5.dp, if (onDark) Color.White.copy(alpha = 0.7f) else MMInk.Secondary, CircleShape),
            )
        }
        Text(
            status.label,
            style = mmFont(12.5f, FontWeight.Medium),
            color = if (onDark) Color.White.copy(alpha = 0.85f) else MMInk.Text,
        )
    }
}

/** iOS case-file caption: 12 semibold, tracked, uppercase, secondary. */
@Composable
internal fun MaintenanceCaption(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        style = mmFont(12f, FontWeight.SemiBold, tracking = 0.6f),
        color = MMInk.Secondary,
        modifier = modifier.semantics { heading() },
    )
}

/** A small clipped thumbnail (iOS `MMCaseThumb`), or the quiet document placeholder when there is no photo. */
@Composable
internal fun MaintenanceThumbTile(thumb: MaintenanceThumb?, side: Dp, modifier: Modifier = Modifier, contentDescription: String? = null) {
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier
            .size(side)
            .clip(shape)
            .background(MMInk.Field)
            .border(0.75.dp, Color.Black.copy(alpha = 0.06f), shape),
        contentAlignment = Alignment.Center,
    ) {
        if (thumb != null) {
            AsyncImage(
                model = rememberSignedImageRequest(thumb.url, thumb.path),
                contentDescription = contentDescription,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Icon(Icons.Outlined.Description, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(18.dp))
        }
    }
}

/**
 * iOS `MMCaseRow`: the case's newest photo (or a document placeholder; never a stand-in photo), the title, a quiet
 * line (category · reported date), the status mark and photo count, a chevron. Read once by TalkBack.
 */
@Composable
internal fun MaintenanceCaseRow(
    title: String,
    line: String,
    photoCount: Int,
    status: MaintenanceCaseStatus,
    thumb: MaintenanceThumb?,
    onClick: () -> Unit,
) {
    val large = mmIsLargeFont()
    Row(
        Modifier
            .fillMaxWidth()
            .mmPressable(onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (!large) {
            MaintenanceThumbTile(thumb = thumb?.takeIf { photoCount > 0 }, side = 60.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                title,
                style = mmFont(16f, FontWeight.SemiBold),
                color = MMInk.Text,
                maxLines = if (large) 4 else 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(line, style = mmFont(13f), color = MMInk.Secondary)
            Row(
                Modifier.padding(top = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                MaintenanceStatusMark(status)
                Text(maintenancePhotoCountText(photoCount), style = mmFont(12.5f), color = MMInk.Secondary)
            }
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MMInk.Secondary.copy(alpha = 0.6f),
            modifier = Modifier.padding(top = 2.dp).size(20.dp),
        )
    }
}

/**
 * iOS `MMCaseTimelineRow`: a rail mark (filled when it happened, hollow while pending), the event, its date
 * underneath and an optional quiet line. Stack inside an MMPanel; the rail joins between rows.
 */
@Composable
internal fun MaintenanceTimelineRow(event: MaintenanceCaseEvent, isFirst: Boolean, isLast: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .semantics(mergeDescendants = true) {
                if (event.isPending) contentDescription = "${event.title}, pending"
            },
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(Modifier.width(10.dp).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.width(1.5.dp).height(5.dp).background(if (isFirst) Color.Transparent else MMInk.Separator))
            Box(
                Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(if (event.isPending) MMInk.Card else MMInk.Text)
                    .border(1.5.dp, if (event.isPending) MMInk.Secondary else MMInk.Text, CircleShape),
            )
            Box(Modifier.width(1.5.dp).weight(1f).background(if (isLast) Color.Transparent else MMInk.Separator))
        }
        Column(
            Modifier
                .weight(1f)
                .padding(bottom = if (isLast) 0.dp else 20.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                event.title,
                style = mmFont(15.5f, if (event.isPending) FontWeight.Normal else FontWeight.SemiBold),
                color = if (event.isPending) MMInk.Secondary else MMInk.Text,
            )
            event.dateText?.let { Text(it, style = mmFont(13f), color = MMInk.Secondary) }
            event.detail?.takeIf { it.isNotEmpty() }?.let {
                Text(it, style = mmFont(14f), color = MMInk.Text.copy(alpha = 0.8f), modifier = Modifier.padding(top = 3.dp))
            }
        }
    }
}

/** iOS `MMField` on the light sheet: a label above, a placeholder inside, ink text on white. */
@Composable
internal fun MaintenanceField(
    title: String,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    multiline: Boolean = false,
    enabled: Boolean = true,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = mmFont(13f, FontWeight.Medium), color = MMInk.Secondary)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            placeholder = { Text(placeholder, style = mmFont(15.5f), color = MMInk.Secondary.copy(alpha = 0.8f)) },
            textStyle = mmFont(15.5f).copy(color = MMInk.Text),
            singleLine = !multiline,
            minLines = if (multiline) 3 else 1,
            maxLines = if (multiline) 8 else 1,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MMInk.Text,
                unfocusedBorderColor = MMInk.Separator,
                disabledBorderColor = MMInk.Separator,
                focusedTextColor = MMInk.Text,
                unfocusedTextColor = MMInk.Text,
                disabledTextColor = MMInk.Text.copy(alpha = 0.6f),
                cursorColor = MMInk.Text,
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White,
                disabledContainerColor = Color.White,
            ),
        )
    }
}

/** The category chips (iOS `categoryPicker`): they wrap, so no option hides off the edge. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun MaintenanceCategoryChips(
    selected: MaintenanceCategory,
    onSelect: (MaintenanceCategory) -> Unit,
    enabled: Boolean = true,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Category", style = mmFont(13f, FontWeight.Medium), color = MMInk.Secondary)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MaintenanceCategory.entries.forEach { category ->
                val isSelected = category == selected
                Box(
                    Modifier
                        .heightIn(min = 36.dp)
                        .clip(CircleShape)
                        .background(if (isSelected) MMInk.Text else MMInk.Card)
                        .border(0.75.dp, if (isSelected) MMInk.Text else MMInk.CardStroke, CircleShape)
                        .mmPressable(enabled = enabled, role = Role.RadioButton) { onSelect(category) }
                        .semantics { this.selected = isSelected }
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        category.raw,
                        style = mmFont(14f, if (isSelected) FontWeight.SemiBold else FontWeight.Normal),
                        color = if (isSelected) Color.White else MMInk.Text,
                    )
                }
            }
        }
    }
}
