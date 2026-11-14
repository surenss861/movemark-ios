package com.surensureshkumar.movemark

import androidx.lifecycle.lifecycleScope
import com.surensureshkumar.movemark.features.auth.social.SocialBrowserSession
import kotlinx.coroutines.launch
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import com.surensureshkumar.movemark.core.design.MMTheme
import com.surensureshkumar.movemark.core.navigation.MoveMarkNavHost
import com.surensureshkumar.movemark.features.auth.PasswordResetLink
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A social return is offered even on a recreated Activity (the attempt may still be waiting in its
        // ViewModel; a repeat of the same link is ignored). A reset link only when it launched the app, not again
        // after a configuration change.
        // Debug builds only: log the crash-report payload Sentry would send, and send nothing (CrashReporting).
        if (BuildConfig.DEBUG && savedInstanceState == null && intent?.getBooleanExtra("movemark.sentry_selftest", false) == true) {
            Thread { com.surensureshkumar.movemark.core.CrashReporting.runSelfTest(applicationContext, BuildConfig.DEBUG) }.start()
        }
        val wasSocialReturn = SocialBrowserSession.offer(intent?.data)
        if (savedInstanceState == null && !wasSocialReturn) PasswordResetLink.offer(intent?.dataString)
        // System bars follow the app's surfaces, not the phone's theme: MoveMark has one dark theme, and everything
        // under the bars is dark, so the icons are light even on a light-mode phone. A future light screen must set
        // its own appearance (WindowCompat.getInsetsController) and restore it on leaving.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        setContent {
            MMTheme {
                MoveMarkNavHost()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        lifecycleScope.launch { SocialBrowserSession.hostResumed() }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!SocialBrowserSession.offer(intent.data)) PasswordResetLink.offer(intent.dataString)
    }
}
