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
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun OnboardingNameScreen(
    onContinue: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val isSaving by viewModel.isSaving.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    var name by remember { mutableStateOf("") }

    // 1.4 grammar (iOS MMScreen): the dark header carries the question, the light sheet the field and one action.
    MMScreen(
        title = "What should we call you?",
        lines = listOf("Your name appears on reports and proof receipts."),
        modifier = Modifier.imePadding(),
    ) {
        MMTextField(
            value = name,
            onValueChange = {
                name = it
                if (errorMessage != null) viewModel.clearError()
            },
            label = "Your name",
            onLight = true,
        )
        errorMessage?.let { msg ->
            Spacer(Modifier.height(8.dp))
            Text(text = msg, color = MMInk.Danger, fontSize = 13.sp)
        }
        Spacer(Modifier.height(20.dp))
        MMPrimaryButton(
            title = "Continue",
            onClick = { viewModel.saveName(name, onContinue) },
            isLoading = isSaving,
            enabled = name.isNotBlank() && !isSaving,
        )
    }
}
