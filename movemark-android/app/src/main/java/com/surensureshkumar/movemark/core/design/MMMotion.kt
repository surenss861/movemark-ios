package com.surensureshkumar.movemark.core.design

import android.content.Context
import android.provider.Settings
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

object MMMotion {
    fun isReduceMotionEnabled(context: Context): Boolean =
        runCatching {
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ) == 0f
        }.getOrDefault(false)

    @Composable
    fun rememberReduceMotion(): Boolean {
        val context = LocalContext.current
        return remember(context) { isReduceMotionEnabled(context) }
    }

    @Composable
    fun receiptEnterSpec(reduceMotion: Boolean): FiniteAnimationSpec<Float> =
        if (reduceMotion) tween(0) else spring(dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow)

    @Composable
    fun checkPopSpec(reduceMotion: Boolean): FiniteAnimationSpec<Float> =
        if (reduceMotion) tween(0) else spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMedium)

    @Composable
    fun welcomeEnterSpec(reduceMotion: Boolean, durationMillis: Int = 480): FiniteAnimationSpec<Float> =
        if (reduceMotion) tween(0) else tween(durationMillis = durationMillis)

    @Composable
    fun welcomeTagEnterSpec(reduceMotion: Boolean): FiniteAnimationSpec<Float> =
        if (reduceMotion) tween(0) else spring(dampingRatio = 0.78f, stiffness = Spring.StiffnessMedium)
}
