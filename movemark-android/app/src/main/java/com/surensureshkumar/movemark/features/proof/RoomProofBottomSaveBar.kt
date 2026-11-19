package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle

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
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.08f),
                    start = androidx.compose.ui.geometry.Offset(0f, 0f),
                    end = androidx.compose.ui.geometry.Offset(size.width, 0f),
                    strokeWidth = 1f,
                )
            }
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        statusLine?.takeIf { it.isNotBlank() }?.let { line ->
            val isError = isFailed || line.contains("couldn't", ignoreCase = true)
            val isPartialMsg = line.contains(" of ") && line.contains("saved")
            Text(
                line,
                color = when {
                    isError -> MMColors.SemanticDanger
                    isPartialMsg -> MMColors.SemanticWarning
                    else -> MMColors.TextSecondary
                },
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(bottom = 10.dp),
            )
        }

        MMButton(
            text = saveButtonLabel,
            onClick = onSave,
            loading = isBusy,
            enabled = photoCount > 0 && !isBusy && !isPartial,
        )

        if (isPartial) {
            Spacer(Modifier.height(8.dp))
            MMButton(
                text = "Continue with saved proof",
                onClick = onContinueWithSaved,
            )
            Spacer(Modifier.height(8.dp))
            MMButton(
                text = RoomProofUploadMessages.RETRY_LABEL,
                onClick = onRetry,
                style = MMButtonStyle.Secondary,
            )
        } else if (isFailed) {
            Spacer(Modifier.height(8.dp))
            MMButton(
                text = RoomProofUploadMessages.RETRY_LABEL,
                onClick = onRetry,
                enabled = photoCount > 0,
            )
        }
    }
}
