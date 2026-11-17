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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Hero = Color(0xFF161817)
private val Sheet = Color(0xFFF8F8F8)
private val Ink = Color(0xFF141415)
private val Quiet = Color(0xFF7E7F80)
private val Lime = Color(0xFFCAE36C)
private val OnLime = Color(0xFF111608)

internal const val STARTUP_OFFLINE_TITLE = "Can’t reach MoveMark"
internal const val STARTUP_OFFLINE_BODY =
    "Your records are safe and nothing on this phone is lost. MoveMark will open your Vault as soon as you’re back online."

@Composable
fun StartupOfflineScreen(isRetrying: Boolean, onRetry: () -> Unit, onSignOut: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Sheet).testTag("startup.offline")) {
        Column(
            Modifier.fillMaxWidth().background(Hero).statusBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 32.dp, bottom = 40.dp),
        ) {
            Text("MoveMark", color = Color.White.copy(alpha = 0.62f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.padding(top = 8.dp))
            Text(
                STARTUP_OFFLINE_TITLE,
                color = Color.White,
                fontSize = 30.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { heading() },
            )
        }
        Text(
            STARTUP_OFFLINE_BODY,
            color = Ink,
            fontSize = 16.sp,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 22.dp).weight(1f),
        )
        Column(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.fillMaxWidth().heightIn(min = 52.dp)
                    .background(if (isRetrying) Lime.copy(alpha = 0.45f) else Lime, RoundedCornerShape(26.dp))
                    .clickable(enabled = !isRetrying, role = Role.Button, onClick = onRetry)
                    .testTag("startup.offline.retry"),
                contentAlignment = Alignment.Center,
            ) {
                Text(if (isRetrying) "Trying…" else "Try again", color = OnLime, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
            TextButton(onClick = onSignOut, enabled = !isRetrying) { Text("Sign out", color = Quiet) }
        }
    }
}
