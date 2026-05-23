package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
    androidx.compose.runtime.LaunchedEffect(initialMode) {
        viewModel.setMode(initialMode)
    }
    val mode by viewModel.mode.collectAsState()
    val email by viewModel.email.collectAsState()
    val password by viewModel.password.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val message by viewModel.message.collectAsState()

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 32.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            TextButton(onClick = onDismiss) { Text("Back", color = MMColors.TextSecondary) }
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (mode == AuthMode.SignUp) "Create your proof vault" else "Sign in",
                style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (mode == AuthMode.SignUp) {
                    "Save room photos, lease docs, and reports under one rental."
                } else {
                    "Continue your proof vault."
                },
                color = MMColors.TextSecondary,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (mode == AuthMode.SignUp) {
                    "Your move-in proof saves here."
                } else {
                    "Sign in to continue saving proof."
                },
                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                color = MMColors.TextSecondary,
            )
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
                text = if (mode == AuthMode.SignUp) "Create account" else "Sign in",
                onClick = viewModel::submit,
                loading = loading,
            )
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = viewModel::resetPassword) {
                Text("Forgot password?", color = MMColors.TextSecondary)
            }
        }
    }
}
