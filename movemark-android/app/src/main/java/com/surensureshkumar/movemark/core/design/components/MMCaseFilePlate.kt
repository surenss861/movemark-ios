package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors

@Composable
fun MMCaseFilePlate(
    modifier: Modifier = Modifier,
    emphasis: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier
            .fillMaxWidth()
            .shadow(
                elevation = if (emphasis) 16.dp else 6.dp,
                shape = shape,
                ambientColor = Color(0xFF07120E),
                spotColor = Color(0xFF07120E),
            )
            .clip(shape)
            .background(MMColors.SurfaceRaised)
            .background(
                if (emphasis) {
                    Brush.radialGradient(
                        colors = listOf(MMColors.Primary.copy(alpha = 0.12f), Color.Transparent),
                        center = Offset(90f, 0f),
                        radius = 520f,
                    )
                } else {
                    Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                },
            )
            .border(
                width = 0.5.dp,
                color = Color.White.copy(alpha = if (emphasis) 0.12f else 0.08f),
                shape = shape,
            )
            .padding(18.dp),
        content = content,
    )
}
