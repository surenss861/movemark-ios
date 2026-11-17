/**
 * @file First-run building blocks that mirror iOS 1.4 controls Android's design system doesn't have yet: MMChoiceCard
 *       (moment picker), MMSelectRow (room picker), MMField with a placeholder (rental setup) and MMChip (Other room).
 *       Kept internal to first run so they never collide with shared components added elsewhere.
 * @domain onboarding-auth
 * @status wip
 */
package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMRowChevron
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.mmLines
import com.surensureshkumar.movemark.core.design.mmPressable

/** iOS MMChoiceCard: icon tile, semibold title, one line under it, chevron; the whole card is the button. */
@Composable
internal fun FirstRunChoiceCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    enabled: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(MMMetrics.CardRadius)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 84.dp)
            .alpha(if (enabled) 1f else 0.5f)
            .clip(shape)
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, shape)
            .testTag(tag)
            .mmPressable(enabled = enabled, onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (!mmIsLargeFont()) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MMInk.Field),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = MMInk.Text.copy(alpha = 0.8f), modifier = Modifier.size(20.dp))
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = mmFont(17f, FontWeight.SemiBold), color = MMInk.Text)
            Text(subtitle, style = mmFont(14f), color = MMInk.Secondary)
        }
        Spacer(Modifier.width(8.dp))
        MMRowChevron()
    }
}

/** iOS MMSelectRow: title (semibold when selected) and an ink checkmark that appears on the selected row. */
@Composable
internal fun FirstRunSelectRow(
    title: String,
    selected: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = MMMetrics.RowHeight)
            .mmPressable(role = Role.RadioButton, onClick = onClick)
            .semantics(mergeDescendants = true) { this.selected = selected }
            .testTag(tag)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = mmFont(16f, if (selected) FontWeight.SemiBold else FontWeight.Normal),
            color = MMInk.Text,
            maxLines = mmLines(2),
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        Icon(
            Icons.Filled.Check,
            contentDescription = null,
            tint = MMInk.Text,
            modifier = Modifier.size(17.dp).alpha(if (selected) 1f else 0f),
        )
    }
}

/** iOS MMField: a caption above, the placeholder inside a white rounded field. */
@Composable
internal fun FirstRunField(
    title: String,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Words,
    imeAction: ImeAction = ImeAction.Next,
    onImeAction: (() -> Unit)? = null,
    tag: String? = null,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = mmFont(13f, FontWeight.Medium), color = MMInk.Secondary)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, style = mmFont(16f), color = MMInk.Secondary.copy(alpha = 0.7f)) },
            textStyle = mmFont(16f).copy(color = MMInk.Text),
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            keyboardOptions = KeyboardOptions(capitalization = capitalization, autoCorrectEnabled = false, imeAction = imeAction),
            keyboardActions = if (onImeAction != null) KeyboardActions(onAny = { onImeAction() }) else KeyboardActions.Default,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MMInk.Text,
                unfocusedBorderColor = MMInk.CardStroke,
                focusedTextColor = MMInk.Text,
                unfocusedTextColor = MMInk.Text,
                cursorColor = MMInk.Text,
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .then(if (tag != null) Modifier.testTag(tag) else Modifier),
        )
    }
}

/** iOS MMChip: ink capsule when selected, white with a hairline otherwise. */
@Composable
internal fun FirstRunChip(title: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .heightIn(min = 48.dp)
            .mmPressable(onClick = onClick)
            .semantics { this.selected = selected },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            style = mmFont(14f, if (selected) FontWeight.SemiBold else FontWeight.Normal),
            color = if (selected) Color.White else MMInk.Text,
            modifier = Modifier
                .clip(CircleShape)
                .background(if (selected) MMInk.Text else MMInk.Card)
                .border(1.dp, if (selected) Color.Transparent else MMInk.CardStroke, CircleShape)
                .heightIn(min = 36.dp)
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}
