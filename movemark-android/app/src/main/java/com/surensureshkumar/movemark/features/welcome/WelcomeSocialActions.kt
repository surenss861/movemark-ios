package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.features.auth.social.SocialProvider

private val GoogleNeutral = Color(0xFFF2F2F2)

/** State for the "or continue with" block on Welcome. Null means the block is hidden (Release, or no probe). */
data class WelcomeSocialState(
    val busyProvider: SocialProvider? = null,
    val errorMessage: String? = null,
)

/*
 * Google's Neutral button (#F2F2F2, no stroke, #1F1F1F label) with the official "G" from Google's sign-in
 * branding pack (res/drawable-*dpi/google_signin_mark_neutral.png; its #F2F2F2 tile is the button fill).
 * Same geometry as iOS. Apple is not shown on Android until its flow exists (SocialProvider.androidShown).
 */
@Composable
fun WelcomeSocialActions(
    state: WelcomeSocialState,
    onSelect: (SocialProvider) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().clearAndSetSemantics {},
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.16f)))
            Text(
                "or continue with",
                fontSize = 12.5.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.16f)))
        }
        SocialProvider.androidShown.forEach { provider ->
            val busy = state.busyProvider == provider
            OutlinedButton(
                onClick = { onSelect(provider) },
                enabled = state.busyProvider == null,
                shape = RoundedCornerShape(MMSpacing.CornerRadius.dp),
                border = null,
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = GoogleNeutral,
                    contentColor = Color(0xFF1F1F1F),
                    disabledContainerColor = GoogleNeutral.copy(alpha = if (busy) 1f else 0.55f),
                    disabledContentColor = Color(0xFF1F1F1F).copy(alpha = if (busy) 1f else 0.55f),
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    // A minimum, not a fixed height: at large font scales the label wraps instead of being clipped (F29).
                    .heightIn(min = MMSpacing.ButtonHeight.dp)
                    .testTag("welcome.social.${provider.id}"),
            ) {
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = Color(0xFF1F1F1F))
                } else {
                    if (provider == SocialProvider.GOOGLE) {
                        Image(
                            painter = painterResource(R.drawable.google_signin_mark_neutral),
                            contentDescription = null,
                            modifier = Modifier.size(40.dp),
                        )
                        Spacer(Modifier.width(2.dp))
                    }
                    // Explicit: the app theme's text style is light-on-dark and would override the button's content colour.
                    Text(
                        provider.buttonTitle,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(0xFF1F1F1F),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                }
            }
        }
        state.errorMessage?.let {
            Text(it, fontSize = 13.sp, color = MMColors.TextSecondary, modifier = Modifier.testTag("welcome.social.error"))
        }
    }
}
