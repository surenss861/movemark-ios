package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import com.surensureshkumar.movemark.features.auth.social.SocialProvider

/*
 * Welcome (iOS WelcomeScreen), in the one light system: brand -> headline and description -> the move-in image card
 * -> actions docked at the foot, all on the soft off-white page. No photograph behind text or buttons.
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
    val reduceMotion = MMMotion.rememberReduceMotion()
    var visible by remember { mutableStateOf(reduceMotion) }
    LaunchedEffect(reduceMotion) { visible = true }
    val pageAlpha by animateFloatAsState(
        if (visible) 1f else 0f, MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 400), label = "welcomeFade",
    )

    MMLightSystemBars(lightNavigationBar = true, lightStatusBar = true)

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(MMInk.Sheet)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        val compact = maxHeight < 700.dp
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
                    .padding(horizontal = MMMetrics.Inset)
                    .padding(bottom = 16.dp),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Spacer(Modifier.height(if (compact) 12.dp else minHeight * 0.06f))
                    Wordmark()
                    // The same deliberate two-line break as iOS, on any width; read aloud as one sentence.
                    Text(
                        text = MoveMarkGrowthCopy.WELCOME_HEADLINE_BROKEN,
                        fontSize = 34.sp,
                        lineHeight = 38.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Text,
                        modifier = Modifier.padding(top = 18.dp),
                    )
                    Text(
                        text = MoveMarkGrowthCopy.WELCOME_BODY,
                        fontSize = 15.5.sp,
                        lineHeight = 21.sp,
                        color = MMInk.Secondary,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                    WelcomeProofCard(
                        compact = compact,
                        modifier = Modifier.padding(top = if (compact) 18.dp else 24.dp),
                    )
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 22.dp),
                ) {
                    MMPrimaryButton(title = MoveMarkGrowthCopy.WELCOME_CTA, onClick = onStartMoveIn)
                    if (social != null) {
                        WelcomeSocialActions(
                            state = social,
                            onSelect = onSocial,
                            modifier = Modifier.padding(top = 14.dp),
                        )
                    }
                    TextButton(
                        onClick = onSignIn,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(top = 4.dp),
                    ) {
                        Text(
                            MoveMarkGrowthCopy.WELCOME_SECONDARY_CTA,
                            style = mmFont(15.5f, FontWeight.Medium),
                            color = MMInk.Secondary,
                            textAlign = TextAlign.Center,
                        )
                    }
                    // Short screens with the social block need this line's height, as on iOS.
                    if (!(compact && social != null)) {
                        Text(
                            MoveMarkGrowthCopy.WELCOME_TRUST_LINE,
                            style = mmFont(12.5f),
                            color = MMInk.Secondary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
    }
}

/**
 * iOS MMWordmark, ink on light. The mark's first panel is off-white, so on the light page it sits on a small ink
 * tile (the app icon's own treatment) instead of vanishing into the page.
 */
@Composable
private fun Wordmark() {
    val size = 21f
    Row(
        Modifier.clearAndSetSemantics { contentDescription = "MoveMark" },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size((size * 1.24f).dp)
                .clip(RoundedCornerShape((size * 0.3f).dp))
                .background(MMInk.Text),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.movemark_mark),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size((size * 0.74f).dp),
            )
        }
        Spacer(Modifier.width((size * 0.42f).dp))
        Text(
            "MoveMark",
            fontSize = size.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMInk.Text,
        )
    }
}
