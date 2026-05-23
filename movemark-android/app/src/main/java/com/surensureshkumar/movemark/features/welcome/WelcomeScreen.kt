package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton

@Composable
fun WelcomeScreen(
    onStartMoveIn: () -> Unit,
    onSignIn: () -> Unit,
) {
    val reduceMotion = MMMotion.rememberReduceMotion()
    var cardVisible by remember { mutableStateOf(reduceMotion) }
    var tagsVisible by remember { mutableStateOf(reduceMotion) }
    var copyVisible by remember { mutableStateOf(reduceMotion) }
    var ctaVisible by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(reduceMotion) {
        if (reduceMotion) {
            cardVisible = true
            tagsVisible = true
            copyVisible = true
            ctaVisible = true
            return@LaunchedEffect
        }
        cardVisible = true
        kotlinx.coroutines.delay(140)
        tagsVisible = true
        kotlinx.coroutines.delay(80)
        copyVisible = true
        kotlinx.coroutines.delay(100)
        ctaVisible = true
    }

    val copyAlpha by animateFloatAsState(
        targetValue = if (copyVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 440),
        label = "copyAlpha",
    )
    val copyOffsetY by animateFloatAsState(
        targetValue = if (copyVisible) 0f else 8f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 440),
        label = "copyOffset",
    )
    val ctaAlpha by animateFloatAsState(
        targetValue = if (ctaVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 420),
        label = "ctaAlpha",
    )
    val ctaOffsetY by animateFloatAsState(
        targetValue = if (ctaVisible) 0f else 10f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 420),
        label = "ctaOffset",
    )

    MMBackground {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
        ) {
            val density = LocalDensity.current
            val usableHeightPx = with(density) { maxHeight.toPx() - 12.dp.toPx() }
            val heroHeight = with(density) {
                (usableHeightPx * 0.34f - 56.dp.toPx())
                    .coerceAtLeast(200.dp.toPx())
                    .toDp()
            }
            val horizontalPad = 20.dp
            val cardMaxWidth = minOf(maxWidth - horizontalPad * 2, 420.dp)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = horizontalPad)
                    .padding(top = 14.dp, bottom = 24.dp),
            ) {
                BrandRow(
                    visible = cardVisible,
                    reduceMotion = reduceMotion,
                    modifier = Modifier.padding(bottom = 14.dp),
                )

                WelcomeDepositCaseFile(
                    heroHeight = heroHeight,
                    cardVisible = cardVisible,
                    tagsVisible = tagsVisible,
                    reduceMotion = reduceMotion,
                    modifier = Modifier.widthIn(max = cardMaxWidth),
                )

                Column(
                    modifier = Modifier
                        .padding(top = 34.dp)
                        .alpha(copyAlpha)
                        .offset(y = copyOffsetY.dp),
                ) {
                    Text(
                        text = "Prove what was already there.",
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold,
                        color = MMColors.TextPrimary,
                        lineHeight = 36.sp,
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = "Take move-in photos now. Make a report when you need it.",
                        style = androidx.compose.material3.MaterialTheme.typography.bodyLarge,
                        color = MMColors.TextSecondary,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "Old damage becomes saved proof.",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Medium,
                        color = MMColors.TextSecondary.copy(alpha = 0.9f),
                    )
                }

                Spacer(Modifier.weight(1f))

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 18.dp)
                        .alpha(ctaAlpha)
                        .offset(y = ctaOffsetY.dp),
                ) {
                    MMButton(text = "Start move-in proof", onClick = onStartMoveIn)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 22.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
                    ) {
                        Text(
                            "Already have an account?",
                            fontSize = 13.sp,
                            color = MMColors.TextSecondary.copy(alpha = 0.88f),
                        )
                        TextButton(onClick = onSignIn) {
                            Text(
                                "Sign in",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Medium,
                                color = MMColors.Primary.copy(alpha = 0.95f),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BrandRow(
    visible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion, durationMillis = 400),
        label = "brandAlpha",
    )
    Row(
        modifier = modifier.alpha(alpha),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(R.drawable.movemark_logo),
            contentDescription = "MoveMark",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .size(35.dp)
                .clip(RoundedCornerShape(8.dp)),
        )
        Spacer(Modifier.size(10.dp))
        Text(
            "MoveMark",
            fontSize = 20.5.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextPrimary,
        )
    }
}
