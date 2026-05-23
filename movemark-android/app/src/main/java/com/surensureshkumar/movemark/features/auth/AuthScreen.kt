package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun AuthScreen(
    initialMode: AuthMode,
    onDismiss: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    LaunchedEffect(initialMode) {
        viewModel.setMode(initialMode)
    }
    val mode by viewModel.mode.collectAsState()
    val email by viewModel.email.collectAsState()
    val password by viewModel.password.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val message by viewModel.message.collectAsState()
    val isSignUp = mode == AuthMode.SignUp

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 32.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            TextButton(onClick = onDismiss) { Text("Back", color = MMColors.TextSecondary) }
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (isSignUp) "Create your proof vault" else "Continue your proof vault",
                style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (isSignUp) {
                    "Save room photos, lease docs, and reports under one rental."
                } else {
                    "Pick up where your room proof left off."
                },
                color = MMColors.TextSecondary,
            )
            Spacer(Modifier.height(20.dp))
            AuthProofSummaryCard(mode = mode)
            Spacer(Modifier.height(24.dp))
            MMTextField(email, viewModel::setEmail, "Email", keyboardType = KeyboardType.Email)
            Spacer(Modifier.height(12.dp))
            MMTextField(password, viewModel::setPassword, "Password", isPassword = true)
            message?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, color = MMColors.SemanticDanger, style = androidx.compose.material3.MaterialTheme.typography.bodyMedium)
            }
            Spacer(Modifier.height(24.dp))
            MMButton(
                text = if (isSignUp) "Create private vault" else "Continue proof vault",
                onClick = viewModel::submit,
                loading = loading,
            )
            if (!isSignUp) {
                Spacer(Modifier.height(8.dp))
                TextButton(onClick = viewModel::resetPassword) {
                    Text("Forgot password?", color = MMColors.TextSecondary)
                }
            }
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = {
                    viewModel.setMode(if (isSignUp) AuthMode.SignIn else AuthMode.SignUp)
                },
            ) {
                Text(
                    text = if (isSignUp) "Already have an account? Sign in" else "Need an account? Create one",
                    color = MMColors.Primary,
                )
            }
        }
    }
}
