package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMPrimaryButton

@Composable
fun RoomProofBottomSaveBar(
    saveButtonLabel: String,
    statusLine: String?,
    photoCount: Int,
    isBusy: Boolean,
    isPartial: Boolean,
    isFailed: Boolean,
    onSave: () -> Unit,
    onContinueWithSaved: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            // Floats over the evidence (translucent, hairline on top), like the iOS material bar.
            .background(MMColors.AppBackgroundRaised.copy(alpha = 0.94f))
            .drawBehind {
                drawLine(
                    color = Color.White.copy(alpha = 0.08f),
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset(size.width, 0f),
                    strokeWidth = 1f,
                )
            }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        val line = statusLine?.takeIf { it.isNotBlank() }
        if ((isPartial || isFailed) && line != null) {
            // One calm notice (iOS partial-save notice): what saved, what needs a retry; the retry sits inside it.
            UploadNotice(message = line, onRetry = if (isPartial) onRetry else null)
        } else if (line != null) {
            Text(line, color = MMColors.TextSecondary, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }

        // Exactly one lime action.
        when {
            isPartial -> MMPrimaryButton(title = "Continue with saved proof", onClick = onContinueWithSaved)
            isFailed -> MMPrimaryButton(
                title = RoomProofUploadMessages.RETRY_LABEL,
                onClick = onRetry,
                enabled = photoCount > 0,
                modifier = Modifier.testTag("room.retry"),
            )
            else -> MMPrimaryButton(
                title = saveButtonLabel,
                onClick = onSave,
                isLoading = isBusy,
                enabled = photoCount > 0 && !isBusy,
            )
        }
    }
}

@Composable
private fun UploadNotice(message: String, onRetry: (() -> Unit)?) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.06f), shape)
            .border(0.75.dp, Color.White.copy(alpha = 0.12f), shape)
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .semantics(mergeDescendants = onRetry == null) { liveRegion = LiveRegionMode.Polite }
            .testTag("room.uploadNotice"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Error, contentDescription = null, tint = Color(0xFFFF8A80), modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(10.dp))
        Text(message, color = Color.White, fontSize = 13.5.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        if (onRetry != null) {
            TextButton(onClick = onRetry, modifier = Modifier.heightIn(min = 48.dp)) {
                Text(RoomProofUploadMessages.RETRY_LABEL, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
