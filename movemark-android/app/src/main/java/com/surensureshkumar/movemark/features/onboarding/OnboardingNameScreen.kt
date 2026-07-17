package com.surensureshkumar.movemark.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun OnboardingNameScreen(
    onContinue: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val isSaving by viewModel.isSaving.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    var name by remember { mutableStateOf("") }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 40.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            // Green accent bar
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.12f)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MMColors.Primary),
            )
            Spacer(Modifier.height(20.dp))

            Text(
                text = "What should we call you?",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = MMColors.TextPrimary,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "Your name appears on reports and proof receipts.",
                fontSize = 15.sp,
                color = MMColors.TextSecondary,
            )

            Spacer(Modifier.height(28.dp))

            MMTextField(
                value = name,
                onValueChange = {
                    name = it
                    if (errorMessage != null) viewModel.clearError()
                },
                label = "Your name",
            )

            errorMessage?.let { msg ->
                Spacer(Modifier.height(8.dp))
                Text(
                    text = msg,
                    color = MMColors.SemanticDanger,
                    fontSize = 13.sp,
                )
            }

            Spacer(Modifier.height(20.dp))

            MMButton(
                text = "Continue",
                onClick = { viewModel.saveName(name, onContinue) },
                loading = isSaving,
                enabled = name.isNotBlank() && !isSaving,
            )
        }
    }
}
