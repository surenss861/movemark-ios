package com.surensureshkumar.movemark.core.design.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.draw.scale
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing

enum class MMButtonStyle { Primary, Secondary }

@Composable
fun MMButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: MMButtonStyle = MMButtonStyle.Primary,
    enabled: Boolean = true,
    loading: Boolean = false,
    height: Dp = MMSpacing.ButtonHeight.dp,
) {
    val shape = RoundedCornerShape(MMSpacing.CornerRadius.dp)
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && enabled && !loading) 0.97f else 1f,
        label = "buttonPress",
    )
    val scaledModifier = modifier
        .scale(scale)
        .fillMaxWidth()
        .height(height)
    when (style) {
        MMButtonStyle.Primary -> Button(
            onClick = onClick,
            enabled = enabled && !loading,
            interactionSource = interactionSource,
            modifier = scaledModifier,
            shape = shape,
            colors = ButtonDefaults.buttonColors(
                containerColor = MMColors.Primary,
                contentColor = androidx.compose.ui.graphics.Color.White,
                disabledContainerColor = MMColors.Primary.copy(alpha = 0.4f),
            ),
        ) {
            if (loading) {
                CircularProgressIndicator(
                    modifier = Modifier.height(22.dp),
                    color = androidx.compose.ui.graphics.Color.White,
                    strokeWidth = 2.dp,
                )
            } else {
                Text(text)
            }
        }
        MMButtonStyle.Secondary -> OutlinedButton(
            onClick = onClick,
            enabled = enabled && !loading,
            interactionSource = interactionSource,
            modifier = scaledModifier,
            shape = shape,
            colors = ButtonDefaults.outlinedButtonColors(contentColor = MMColors.TextPrimary),
        ) {
            Text(text)
        }
    }
}
