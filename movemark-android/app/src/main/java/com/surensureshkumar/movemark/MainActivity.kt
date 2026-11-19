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
        // One light system (owner, 2026-11-18): every screen is light, so the bar icons are dark everywhere. The only
        // dark surface, the full-screen photo viewer, is its own window and sets its own bars.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
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
