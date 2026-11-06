package com.surensureshkumar.movemark

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
        // A reset link that launched the app (not again after a configuration change).
        if (savedInstanceState == null) PasswordResetLink.offer(intent?.dataString)
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        PasswordResetLink.offer(intent.dataString)
    }
}
