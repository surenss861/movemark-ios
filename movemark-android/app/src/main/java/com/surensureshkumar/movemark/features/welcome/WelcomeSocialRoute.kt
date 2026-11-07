package com.surensureshkumar.movemark.features.welcome

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import com.surensureshkumar.movemark.features.auth.social.SocialProbeResult
import com.surensureshkumar.movemark.features.auth.social.SocialProbeRunner
import com.surensureshkumar.movemark.features.auth.social.SocialProvider
import com.surensureshkumar.movemark.features.auth.social.SocialSignInConfig
import com.surensureshkumar.movemark.features.auth.social.SocialSignInException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Welcome plus the probe-only social block. When [SocialSignInConfig.isEnabled] is false (always in Release),
 * this is exactly the original [WelcomeScreen]. A probe sign-in never touches the app session; see SocialSignIn.kt.
 */
@Composable
fun WelcomeRoute(onStartMoveIn: () -> Unit, onSignIn: () -> Unit) {
    if (!SocialSignInConfig.isEnabled) {
        WelcomeScreen(onStartMoveIn = onStartMoveIn, onSignIn = onSignIn)
        return
    }
    val activity = LocalContext.current.findActivity()
    val scope = rememberCoroutineScope()
    val runner = remember { SocialProbeRunner() }
    var busy by remember { mutableStateOf<SocialProvider?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf<SocialProbeResult?>(null) }

    WelcomeScreen(
        onStartMoveIn = onStartMoveIn,
        onSignIn = onSignIn,
        social = WelcomeSocialState(busyProvider = busy, errorMessage = error),
        onSocial = { provider ->
            val probeUrl = SocialSignInConfig.probeAuthUrl
            if (busy != null || probeUrl == null || activity == null) return@WelcomeScreen
            error = null
            busy = provider
            scope.launch {
                try {
                    result = runner.run(activity, provider, probeUrl)
                } catch (e: SocialSignInException.Cancelled) {
                    // Dismissed the sheet; nothing to say.
                } catch (e: CancellationException) {
                    throw e
                } catch (e: NeonAuthException.Rejected) {
                    // Probe only: the refusal code is the evidence the security probe records (e.g. ACCOUNT_NOT_LINKED).
                    error = "${e.message} [${e.code ?: "no code"}]"
                } catch (e: Exception) {
                    error = e.message ?: "Sign-in didn’t finish. Try again."
                } finally {
                    busy = null
                }
            }
        },
    )

    result?.let { r ->
        AlertDialog(
            onDismissRequest = { result = null },
            confirmButton = { TextButton(onClick = { result = null }) { Text("OK") } },
            title = { Text("Probe sign-in") },
            text = { Text("${r.provider.buttonTitle}\nNeon user: ${r.userId}\nEmail: ${r.email}\nSigned out of the probe.") },
        )
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
