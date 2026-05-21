package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle

@Composable
fun WelcomeScreen(
    onStartMoveIn: () -> Unit,
    onContinue: () -> Unit,
) {
    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 48.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(
                    text = "MoveMark",
                    style = androidx.compose.material3.MaterialTheme.typography.displayLarge,
                    color = MMColors.Primary,
                )
                Spacer(Modifier.height(24.dp))
                Text(
                    text = "Prove what was already there.",
                    style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    text = "Take move-in photos now. Make a report when you need it.",
                    style = androidx.compose.material3.MaterialTheme.typography.bodyLarge,
                    color = MMColors.TextSecondary,
                    textAlign = TextAlign.Start,
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                MMButton(text = "Start move-in proof", onClick = onStartMoveIn)
                MMButton(
                    text = "Continue proof vault",
                    onClick = onContinue,
                    style = MMButtonStyle.Secondary,
                )
            }
        }
    }
}
