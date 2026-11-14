package com.surensureshkumar.movemark.features.welcome

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.Composable
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import com.surensureshkumar.movemark.features.auth.social.SocialProvider
import com.surensureshkumar.movemark.features.auth.social.SocialSignInConfig

/** Welcome with the social block. When [SocialSignInConfig.isEnabled] is false this is exactly [WelcomeScreen]. */
@Composable
fun WelcomeRoute(onStartMoveIn: () -> Unit, onSignIn: () -> Unit) {
    if (!SocialSignInConfig.isEnabled) {
        WelcomeScreen(onStartMoveIn = onStartMoveIn, onSignIn = onSignIn)
        return
    }
    val activity = LocalContext.current.findActivity()
    val viewModel: SocialSignInViewModel = hiltViewModel()
    val busy by viewModel.busy.collectAsState()
    val error by viewModel.error.collectAsState()

    WelcomeScreen(
        onStartMoveIn = onStartMoveIn,
        onSignIn = onSignIn,
        social = WelcomeSocialState(busyProvider = busy, errorMessage = error),
        onSocial = { provider ->
            if (activity != null) viewModel.start(activity, provider)
        },
    )
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
