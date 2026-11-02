package com.surensureshkumar.movemark

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
        enableEdgeToEdge()
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
