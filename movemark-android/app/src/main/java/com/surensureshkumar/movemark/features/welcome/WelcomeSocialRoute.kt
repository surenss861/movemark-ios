package com.surensureshkumar.movemark.features.welcome

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.Composable
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.surensureshkumar.movemark.features.auth.social.SocialProvider
import com.surensureshkumar.movemark.features.auth.social.SocialSignInConfig
import com.surensureshkumar.movemark.features.auth.social.SocialSignInException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Welcome with the social block. When [SocialSignInConfig.isEnabled] is false this is exactly [WelcomeScreen]. */
@Composable
fun WelcomeRoute(onStartMoveIn: () -> Unit, onSignIn: () -> Unit) {
    if (!SocialSignInConfig.isEnabled) {
        WelcomeScreen(onStartMoveIn = onStartMoveIn, onSignIn = onSignIn)
        return
    }
    val activity = LocalContext.current.findActivity()
    val viewModel: SocialSignInViewModel = hiltViewModel()
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf<SocialProvider?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    WelcomeScreen(
        onStartMoveIn = onStartMoveIn,
        onSignIn = onSignIn,
        social = WelcomeSocialState(busyProvider = busy, errorMessage = error),
        onSocial = { provider ->
            if (busy != null || activity == null) return@WelcomeScreen
            error = null
            busy = provider
            scope.launch {
                try {
                    viewModel.signIn(activity, provider)
                } catch (e: SocialSignInException.Cancelled) {
                    // Closed the browser; nothing to say.
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    error = e.message ?: "Sign-in didn’t finish. Try again."
                } finally {
                    busy = null
                }
            }
        },
    )
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
