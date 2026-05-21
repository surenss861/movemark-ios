package com.surensureshkumar.movemark

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.surensureshkumar.movemark.core.design.MMTheme
import com.surensureshkumar.movemark.core.navigation.MoveMarkNavHost
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MMTheme {
                MoveMarkNavHost()
            }
        }
    }
}
