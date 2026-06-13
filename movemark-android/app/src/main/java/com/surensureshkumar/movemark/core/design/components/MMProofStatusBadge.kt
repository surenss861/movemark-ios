package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

enum class MMProofStatusTone {
    Success,
    Warning,
    Danger,
    Neutral,
}

@Composable
fun MMProofStatusBadge(
    text: String,
    tone: MMProofStatusTone,
    modifier: Modifier = Modifier,
) {
    val (bg, fg, border) = when (tone) {
        MMProofStatusTone.Success ->
            Triple(MMColors.Primary.copy(0.16f), MMColors.Primary.copy(0.92f), MMColors.Primary.copy(0.48f))
        MMProofStatusTone.Warning ->
            Triple(MMColors.SemanticWarning.copy(0.14f), MMColors.SemanticWarning, MMColors.SemanticWarning.copy(0.45f))
        MMProofStatusTone.Danger ->
            Triple(MMColors.SemanticDanger.copy(0.14f), MMColors.SemanticDanger, MMColors.SemanticDanger.copy(0.45f))
        MMProofStatusTone.Neutral ->
            Triple(MMColors.FieldFill.copy(0.85f), MMColors.TextSecondary, Color.Transparent)
    }
    Text(
        text,
        modifier = modifier
            .background(bg, CircleShape)
            .then(
                if (border != Color.Transparent) {
                    Modifier.border(0.85.dp, border, CircleShape)
                } else {
                    Modifier
                },
            )
            .padding(horizontal = 9.dp, vertical = 5.dp),
        color = fg,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
    )
}
