package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextDecoration
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.features.account.AccountViewModel
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.R
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
    val confirmPassword by viewModel.confirmPassword.collectAsState()
    val message by viewModel.message.collectAsState()
    val isSignUp = mode == AuthMode.SignUp

    val context = androidx.compose.ui.platform.LocalContext.current
    // 1.4 grammar, as iOS AuthContainerView: the dark header carries the title, the light sheet the form and one
    // lime action, then the quiet ways out.
    MMScreen(
        title = if (isSignUp) "Create your private vault" else "Welcome back.",
        lines = listOf(if (isSignUp) "Your rental proof stays tied to your account." else "Continue your proof vault."),
        onBack = onDismiss,
        modifier = Modifier.imePadding(),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            MMTextField(email, viewModel::setEmail, "Email", keyboardType = KeyboardType.Email, onLight = true)
            MMTextField(password, viewModel::setPassword, "Password", isPassword = true, onLight = true)
            if (isSignUp) {
                MMTextField(confirmPassword, viewModel::setConfirmPassword, "Confirm password", isPassword = true, onLight = true)
            }
        }
        if (!isSignUp) {
            TextButton(onClick = viewModel::resetPassword, modifier = Modifier.align(Alignment.End).heightIn(min = 48.dp)) {
                Text("Forgot password?", style = mmFont(14f, FontWeight.Medium), color = MMInk.Text)
            }
        }
        message?.let {
            Text(it, color = MMInk.Danger, style = mmFont(13.5f), modifier = Modifier.padding(top = 10.dp))
        }
        Spacer(Modifier.height(if (isSignUp) 22.dp else 12.dp))
        MMPrimaryButton(
            title = if (isSignUp) "Create vault" else "Continue",
            onClick = viewModel::submit,
            isLoading = loading,
            enabled = !loading,
            modifier = Modifier.testTag("auth.primaryAction"),
        )
        if (isSignUp) {
            Row(
                Modifier.fillMaxWidth().padding(top = 14.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("By continuing, you agree to ", style = mmFont(12.5f), color = MMInk.Secondary)
                Text(
                    "Terms",
                    style = mmFont(12.5f, FontWeight.Medium),
                    color = MMInk.Text,
                    textDecoration = TextDecoration.Underline,
                    modifier = Modifier.clickable(role = Role.Button) {
                        com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.TERMS_URL)
                    },
                )
                Text(" and ", style = mmFont(12.5f), color = MMInk.Secondary)
                Text(
                    "Privacy",
                    style = mmFont(12.5f, FontWeight.Medium),
                    color = MMInk.Text,
                    textDecoration = TextDecoration.Underline,
                    modifier = Modifier.clickable(role = Role.Button) {
                        com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, AccountViewModel.PRIVACY_URL)
                    },
                )
                Text(".", style = mmFont(12.5f), color = MMInk.Secondary)
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(top = if (isSignUp) 6.dp else 10.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(if (isSignUp) "Already have a vault?" else "New to MoveMark?", style = mmFont(14f), color = MMInk.Secondary)
            TextButton(
                onClick = { viewModel.setMode(if (isSignUp) AuthMode.SignIn else AuthMode.SignUp) },
                modifier = Modifier.heightIn(min = 48.dp),
            ) {
                Text(if (isSignUp) "Sign in" else "Create private vault", style = mmFont(14f, FontWeight.SemiBold), color = MMInk.Text)
            }
        }
    }
}
