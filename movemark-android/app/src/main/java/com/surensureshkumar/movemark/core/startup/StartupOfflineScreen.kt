/**
 * @file Where a launch lands when MoveMark can't be reached and nothing on this phone says where the renter belongs.
 *       Recoverable: it re-checks on its own when the connection returns, and offers "Try again" and sign-out. It
 *       never stands in for onboarding or rental setup.
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupRouter.kt]]
 * @tested-by [[StartupOfflineScreenTest.kt]]
 */
package com.surensureshkumar.movemark.core.startup

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMWordmark

// One light system (owner, 2026-11-18): the header is the page itself, ink on soft off-white.
private val Sheet = MMInk.Sheet
private val Ink = MMInk.Text
private val Quiet = MMInk.Secondary
private val Lime = MMInk.Lime
private val OnLime = MMInk.OnLime

internal const val STARTUP_OFFLINE_TITLE = "Can’t reach MoveMark"
internal const val STARTUP_OFFLINE_BODY =
    "Your records are safe and nothing on this phone is lost. MoveMark will open your Vault as soon as you’re back online."

@Composable
fun StartupOfflineScreen(isRetrying: Boolean, onRetry: () -> Unit, onSignOut: () -> Unit) {
    MMLightSystemBars(lightNavigationBar = true, lightStatusBar = true)
    Column(Modifier.fillMaxSize().background(Sheet).testTag("startup.offline")) {
        Column(
            Modifier.fillMaxWidth().statusBarsPadding()
                .padding(start = MMMetrics.Inset, end = MMMetrics.Inset, top = 24.dp, bottom = 8.dp),
        ) {
            MMWordmark(size = 15f)
            Spacer(Modifier.padding(top = 10.dp))
            Text(
                STARTUP_OFFLINE_TITLE,
                color = Ink,
                fontSize = 30.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { heading() },
            )
        }
        Text(
            STARTUP_OFFLINE_BODY,
            color = Quiet,
            fontSize = 16.sp,
            modifier = Modifier.padding(horizontal = MMMetrics.Inset, vertical = 22.dp).weight(1f),
        )
        Column(
            Modifier.fillMaxWidth().background(Sheet).navigationBarsPadding()
                .padding(start = MMMetrics.Inset, end = MMMetrics.Inset, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.fillMaxWidth().heightIn(min = MMMetrics.CtaHeight)
                    .background(if (isRetrying) Lime.copy(alpha = 0.45f) else Lime, CircleShape)
                    .clickable(enabled = !isRetrying, role = Role.Button, onClick = onRetry)
                    .testTag("startup.offline.retry"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (isRetrying) "Trying…" else "Try again",
                    color = OnLime,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 8.dp),
                )
            }
            TextButton(onClick = onSignOut, enabled = !isRetrying, modifier = Modifier.heightIn(min = 48.dp)) { Text("Sign out", color = Quiet) }
        }
    }
}
