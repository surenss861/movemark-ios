package com.surensureshkumar.movemark.features.welcome

import android.app.Activity
import android.content.ContextWrapper
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import com.surensureshkumar.movemark.features.auth.social.SocialProvider

/*
 * Welcome (iOS WelcomeScreen): brand -> headline and description -> the Proof Aperture -> actions docked at the foot.
 * Everything scrolls when it doesn't fit (short phones, large font settings), so no action is ever out of reach.
 */
@Composable
fun WelcomeScreen(
    onStartMoveIn: () -> Unit,
    onSignIn: () -> Unit,
    /** Null hides the social block (Release, or no probe configured). */
    social: WelcomeSocialState? = null,
    onSocial: (SocialProvider) -> Unit = {},
) {
    LightStatusBarIcons()
    val reduceMotion = MMMotion.rememberReduceMotion()
    var visible by remember { mutableStateOf(reduceMotion) }
    var revealed by remember { mutableStateOf(reduceMotion) }
    LaunchedEffect(reduceMotion) {
        visible = true
        if (!reduceMotion) kotlinx.coroutines.delay(450)
        revealed = true
    }
    val pageAlpha by animateFloatAsState(
        if (visible) 1f else 0f, MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 400), label = "welcomeFade",
    )
    val reveal by animateFloatAsState(
        if (revealed) 1f else 0f, if (reduceMotion) tween(0) else tween(800), label = "apertureReveal",
    )

    var rootOrigin by remember { mutableStateOf(Offset.Zero) }
    var aperture by remember { mutableStateOf<Rect?>(null) }

    Box(
        Modifier
            .fillMaxSize()
            .onGloballyPositioned { rootOrigin = it.positionInRoot() },
    ) {
        WelcomeBackdrop(aperture = aperture?.translate(-rootOrigin), reveal = reveal)

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            val compact = maxHeight < 700.dp
            // Large font settings: the caption takes the full width above the frame, as iOS does at AX sizes.
            val stacked = LocalDensity.current.fontScale >= 1.3f
            val minHeight = maxHeight

            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .alpha(pageAlpha),
            ) {
                Column(
                    modifier = Modifier
                        .heightIn(min = minHeight)
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp)
                        .padding(bottom = 16.dp),
                    verticalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column {
                        Spacer(Modifier.height(if (compact) 8.dp else minHeight * 0.1f))
                        Wordmark()
                        // The same deliberate two-line break as iOS, on any width; read aloud as one sentence.
                        Text(
                            text = MoveMarkGrowthCopy.WELCOME_HEADLINE_BROKEN,
                            fontSize = 34.sp,
                            lineHeight = 38.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextPrimary,
                            modifier = Modifier.padding(top = 16.dp),
                        )
                        Text(
                            text = MoveMarkGrowthCopy.WELCOME_BODY,
                            fontSize = 15.5.sp,
                            lineHeight = 21.sp,
                            color = MMColors.TextPrimary.copy(alpha = 0.74f),
                            modifier = Modifier.padding(top = 10.dp),
                        )
                        Hero(
                            compact = compact,
                            stacked = stacked,
                            reveal = reveal,
                            onAperture = { aperture = it },
                            modifier = Modifier.padding(top = if (compact) 14.dp else 20.dp),
                        )
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 18.dp)
                            .padding(horizontal = 10.dp),
                    ) {
                        MMButton(text = MoveMarkGrowthCopy.WELCOME_CTA, onClick = onStartMoveIn, style = MMButtonStyle.Action)
                        if (social != null) {
                            WelcomeSocialActions(
                                state = social,
                                onSelect = onSocial,
                                modifier = Modifier.padding(top = 14.dp),
                            )
                        }
                        TextButton(onClick = onSignIn, modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
                            Text(
                                MoveMarkGrowthCopy.WELCOME_SECONDARY_CTA,
                                fontSize = 15.5.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MMColors.TextPrimary,
                            )
                        }
                        // Short screens with the social block need this line's height, as on iOS.
                        if (!(compact && social != null)) {
                            Text(
                                MoveMarkGrowthCopy.WELCOME_TRUST_LINE,
                                fontSize = 12.5.sp,
                                color = MMColors.TextPrimary.copy(alpha = 0.5f),
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Welcome is always dark, but edge-to-edge picks status-bar icons from the system theme: on a light-mode phone they
 * would be dark on dark. Light icons while Welcome is showing; the previous appearance comes back on leaving.
 */
@Composable
private fun LightStatusBarIcons() {
    val view = LocalView.current
    DisposableEffect(view) {
        val window = generateSequence(view.context) { (it as? ContextWrapper)?.baseContext }
            .filterIsInstance<Activity>().firstOrNull()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previous = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightStatusBars = false
        onDispose { if (previous != null) controller.isAppearanceLightStatusBars = previous }
    }
}

/** iOS MMWordmark: the same mark at 0.74x the type size, 0.38x spacing, seated on the text baseline. */
@Composable
private fun Wordmark() {
    val size = 21f
    Row(Modifier.clearAndSetSemantics { contentDescription = "MoveMark" }) {
        Image(
            painter = painterResource(R.drawable.movemark_mark),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .height((size * 0.74f).dp)
                .alignBy { it.measuredHeight },
        )
        Spacer(Modifier.width((size * 0.38f).dp))
        Text(
            "MoveMark",
            fontSize = size.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White.copy(alpha = 0.85f),
            modifier = Modifier.alignByBaseline(),
        )
    }
}

@Composable
private fun Hero(
    compact: Boolean,
    stacked: Boolean,
    reveal: Float,
    onAperture: (Rect) -> Unit,
    modifier: Modifier = Modifier,
) {
    val frameHeight = if (compact) 92.dp else 128.dp
    val semantics = Modifier
        .testTag("welcome.aperture")
        .clearAndSetSemantics { contentDescription = "Move-in: before anything changes." }
    val frame = Modifier.onGloballyPositioned { onAperture(it.boundsInRoot()) }
    if (stacked) {
        Column(modifier.then(semantics).fillMaxWidth()) {
            ApertureCaption(Modifier.alpha(reveal))
            ApertureMarks(frame.padding(top = 12.dp).fillMaxWidth().height(120.dp), alpha = reveal)
        }
    } else {
        Row(modifier.then(semantics).fillMaxWidth().height(frameHeight), verticalAlignment = Alignment.Bottom) {
            ApertureCaption(Modifier.weight(0.46f).alpha(reveal))
            Spacer(Modifier.width(16.dp))
            ApertureMarks(frame.weight(0.54f).fillMaxHeight(), alpha = reveal)
        }
    }
}
