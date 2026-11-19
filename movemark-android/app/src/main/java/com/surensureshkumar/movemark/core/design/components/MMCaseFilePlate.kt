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
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics

/**
 * The primary card of the one light system (owner, 2026-11-18): white, a 0.75dp hairline, the shared card radius.
 * No shadow, glow or gradient; `emphasis` is kept for callers and no longer changes the surface.
 */
@Composable
fun MMCaseFilePlate(
    modifier: Modifier = Modifier,
    @Suppress("UNUSED_PARAMETER") emphasis: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(MMMetrics.CardRadius)
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MMInk.Card)
            .border(width = 0.75.dp, color = MMInk.CardStroke, shape = shape)
            .padding(18.dp),
        content = content,
    )
}
