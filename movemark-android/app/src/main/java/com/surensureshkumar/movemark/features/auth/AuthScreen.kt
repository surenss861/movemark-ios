package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.features.account.AccountViewModel

/** Everything the auth surface shows (collected from [AuthViewModel]; built directly in tests and previews). */
data class AuthFormState(
    val mode: AuthMode = AuthMode.SignIn,
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val loading: Boolean = false,
    val message: String? = null,
    val info: String? = null,
    val confirmationEmail: String? = null,
    val resetSentTo: String? = null,
    val resendCooldown: Int = 0,
    val resending: Boolean = false,
) {
    /** iOS `headerTitle`. */
    val headerTitle: String
        get() = when {
            confirmationEmail != null || resetSentTo != null -> "Check your email"
            mode == AuthMode.SignUp -> "Create your private vault"
            mode == AuthMode.ResetPassword -> "Reset your password"
            else -> "Welcome back."
        }

    /** iOS `headerSubtitle` ("Open the link on this iPhone." reads "phone" here). */
    val headerSubtitle: String
        get() = when {
            confirmationEmail != null -> "One more step to finish your vault."
            resetSentTo != null -> "Open the link on this phone."
            mode == AuthMode.SignUp -> "Your rental proof stays tied to your account."
            mode == AuthMode.ResetPassword -> "We’ll email you a link to choose a new one."
            else -> "Continue your proof vault."
        }
}

@Composable
fun AuthScreen(
    initialMode: AuthMode,
    onDismiss: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    LaunchedEffect(initialMode) {
        viewModel.start(initialMode)
    }
    val mode by viewModel.mode.collectAsState()
    val email by viewModel.email.collectAsState()
    val password by viewModel.password.collectAsState()
    val confirmPassword by viewModel.confirmPassword.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val message by viewModel.message.collectAsState()
    val info by viewModel.info.collectAsState()
    val confirmationEmail by viewModel.confirmationEmail.collectAsState()
    val resetSentTo by viewModel.resetSentTo.collectAsState()
    val resendCooldown by viewModel.resendCooldown.collectAsState()
    val resending by viewModel.resending.collectAsState()

    AuthContent(
        state = AuthFormState(
            mode = mode,
            email = email,
            password = password,
            confirmPassword = confirmPassword,
            loading = loading,
            message = message,
            info = info,
            confirmationEmail = confirmationEmail,
            resetSentTo = resetSentTo,
            resendCooldown = resendCooldown,
            resending = resending,
        ),
        onDismiss = onDismiss,
        onEmailChange = viewModel::setEmail,
        onPasswordChange = viewModel::setPassword,
        onConfirmPasswordChange = viewModel::setConfirmPassword,
        onSubmit = viewModel::submit,
        onForgotPassword = viewModel::openResetPassword,
        onSwitchMode = viewModel::switchMode,
        onBackToSignInAfterConfirmation = viewModel::backToSignInAfterConfirmation,
        onBackToSignInFromReset = viewModel::backToSignInFromReset,
        onResendReset = viewModel::resendResetLink,
    )
}

/**
 * The auth surface itself, stateless. 1.4 grammar, as iOS `AuthContainerView`: the dark header carries the title, the
 * light sheet the form and one lime action, then the quiet ways out. A sent confirmation or reset link replaces the
 * form with the "Check your email" block.
 */
@Composable
internal fun AuthContent(
    state: AuthFormState,
    onDismiss: () -> Unit = {},
    onEmailChange: (String) -> Unit = {},
    onPasswordChange: (String) -> Unit = {},
    onConfirmPasswordChange: (String) -> Unit = {},
    onSubmit: () -> Unit = {},
    onForgotPassword: () -> Unit = {},
    onSwitchMode: () -> Unit = {},
    onBackToSignInAfterConfirmation: () -> Unit = {},
    onBackToSignInFromReset: () -> Unit = {},
    onResendReset: () -> Unit = {},
) {
    MMScreen(
        title = state.headerTitle,
        lines = listOf(state.headerSubtitle),
        onBack = onDismiss,
        modifier = Modifier.imePadding(),
    ) {
        val confirmationEmail = state.confirmationEmail
        val resetSentTo = state.resetSentTo
        when {
            confirmationEmail != null -> AuthResolvedBlock(
                message = "We sent a confirmation link to $confirmationEmail. Open it to finish creating your vault.",
                actionTitle = "Back to sign in",
                onAction = onBackToSignInAfterConfirmation,
                modifier = Modifier.padding(top = 4.dp).testTag("auth.confirmation"),
            )
            resetSentTo != null -> ResetSentBlock(
                email = resetSentTo,
                state = state,
                onBackToSignIn = onBackToSignInFromReset,
                onResend = onResendReset,
            )
            else -> AuthForm(
                state = state,
                onEmailChange = onEmailChange,
                onPasswordChange = onPasswordChange,
                onConfirmPasswordChange = onConfirmPasswordChange,
                onSubmit = onSubmit,
                onForgotPassword = onForgotPassword,
                onSwitchMode = onSwitchMode,
            )
        }
    }
}

@Composable
private fun ColumnScope.AuthForm(
    state: AuthFormState,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onForgotPassword: () -> Unit,
    onSwitchMode: () -> Unit,
) {
    val mode = state.mode
    val context = LocalContext.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        MMTextField(
            state.email,
            onEmailChange,
            "Email",
            modifier = Modifier.testTag("auth.email"),
            keyboardType = KeyboardType.Email,
            onLight = true,
        )
        if (mode != AuthMode.ResetPassword) {
            MMTextField(
                state.password,
                onPasswordChange,
                "Password",
                modifier = Modifier.testTag("auth.password"),
                isPassword = true,
                onLight = true,
            )
        }
        if (mode == AuthMode.SignUp) {
            MMTextField(
                state.confirmPassword,
                onConfirmPasswordChange,
                "Confirm password",
                modifier = Modifier.testTag("auth.confirmPassword"),
                isPassword = true,
                onLight = true,
            )
        }
    }
    if (mode == AuthMode.SignIn) {
        // Quiet, under the password it's about (iOS `forgotPasswordButton`).
        AuthTextAction(
            title = "Forgot password?",
            onClick = onForgotPassword,
            modifier = Modifier.align(Alignment.End).padding(top = 2.dp).testTag("auth.forgotPassword"),
        )
    }
    if (state.info != null || state.message != null) {
        Column(
            Modifier.padding(top = 18.dp).semantics { liveRegion = LiveRegionMode.Polite },
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            state.info?.let { MMNotice(it, tone = MMNoticeTone.Info) }
            state.message?.let { MMNotice(it, modifier = Modifier.testTag("auth.error")) }
        }
    }
    Spacer(Modifier.height(if (mode == AuthMode.SignIn) 12.dp else 22.dp))
    MMPrimaryButton(
        title = when (mode) {
            AuthMode.SignIn -> "Continue"
            AuthMode.SignUp -> "Create vault"
            AuthMode.ResetPassword -> "Send reset link"
        },
        onClick = onSubmit,
        isLoading = state.loading,
        enabled = !state.loading,
        modifier = Modifier.testTag("auth.primaryAction"),
    )
    if (mode == AuthMode.SignUp) {
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
    PromptRow(
        prompt = when (mode) {
            AuthMode.SignIn -> "New to MoveMark?"
            AuthMode.SignUp -> "Already have a vault?"
            AuthMode.ResetPassword -> "Remembered it?"
        },
        actionTitle = if (mode == AuthMode.SignIn) "Create private vault" else "Sign in",
        onAction = onSwitchMode,
        actionTag = "auth.switchMode",
        modifier = Modifier.padding(top = if (mode == AuthMode.SignUp) 6.dp else 10.dp),
    )
}

/** Neutral by design (iOS `resetSentBlock`): the same words whether or not the address has an account. */
@Composable
private fun ResetSentBlock(
    email: String,
    state: AuthFormState,
    onBackToSignIn: () -> Unit,
    onResend: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
        AuthResolvedBlock(
            message = "If $email has a MoveMark account, a link to choose a new password is on its way. It expires soon.",
            actionTitle = "Back to sign in",
            onAction = onBackToSignIn,
            modifier = Modifier.testTag("auth.resetSent"),
        )
        state.message?.let {
            Box(Modifier.padding(top = 18.dp).semantics { liveRegion = LiveRegionMode.Polite }) {
                MMNotice(it, modifier = Modifier.testTag("auth.error"))
            }
        }
        val waiting = state.resendCooldown > 0
        PromptRow(
            prompt = "Didn’t get it?",
            actionTitle = when {
                state.resending -> "Sending…"
                waiting -> "Resend in ${state.resendCooldown}s"
                else -> "Resend link"
            },
            onAction = onResend,
            actionTag = "auth.resendReset",
            actionEnabled = !waiting && !state.resending,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}

/** iOS `MMResolvedBlock` (no title: the header already says it): a quiet glyph, the message, one secondary action. */
@Composable
private fun AuthResolvedBlock(
    message: String,
    actionTitle: String,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxWidth()) {
        Icon(
            Icons.Outlined.MailOutline,
            contentDescription = null,
            tint = MMInk.Text.copy(alpha = 0.7f),
            modifier = Modifier.size(24.dp),
        )
        Text(
            message,
            style = mmFont(16f),
            color = MMInk.Text,
            modifier = Modifier.padding(top = 12.dp),
        )
        MMSecondaryButton(title = actionTitle, onClick = onAction, modifier = Modifier.padding(top = 18.dp))
    }
}

/** "New to MoveMark?  Create private vault" — a quiet prompt and its text action, centred (iOS `modeSwitchRow`). */
@Composable
private fun PromptRow(
    prompt: String,
    actionTitle: String,
    onAction: () -> Unit,
    actionTag: String,
    modifier: Modifier = Modifier,
    actionEnabled: Boolean = true,
) {
    Row(
        modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(prompt, style = mmFont(14f), color = MMInk.Secondary, textAlign = TextAlign.Center)
        Spacer(Modifier.size(6.dp))
        AuthTextAction(
            title = actionTitle,
            onClick = onAction,
            enabled = actionEnabled,
            tint = if (actionEnabled) MMInk.Text else MMInk.Secondary,
            modifier = Modifier.testTag(actionTag),
        )
    }
}

/** iOS `MMTextAction`: ink, semibold, no fill, a 48dp target. */
@Composable
private fun AuthTextAction(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = MMInk.Text,
) {
    Box(
        modifier
            .heightIn(min = 48.dp)
            .mmPressable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = mmFont(14f, FontWeight.SemiBold), color = tint)
    }
}
