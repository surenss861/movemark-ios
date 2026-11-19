package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.features.auth.social.SocialProvider

/** Google's light-theme button outline: a quiet grey that still reads on the off-white page. */
private val SocialStroke = Color(0xFFDADCE0)

/** State for the "or continue with" block on Welcome. Null means the block is hidden (Release, or no probe). */
data class WelcomeSocialState(
    val busyProvider: SocialProvider? = null,
    val errorMessage: String? = null,
)

/*
 * The provider buttons in the one light system: a white capsule (the primary button's shape), a 1dp grey outline,
 * ink label and the official multicolour Google "G" (res/drawable/ic_google_g.xml, Google's four brand colours).
 * Apple is not shown on Android until its flow exists (SocialProvider.androidShown).
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
            Box(Modifier.weight(1f).height(0.75.dp).background(MMInk.Separator))
            Text(
                "or continue with",
                style = mmFont(12.5f),
                color = MMInk.Secondary,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(Modifier.weight(1f).height(0.75.dp).background(MMInk.Separator))
        }
        SocialProvider.androidShown.forEach { provider ->
            val busy = state.busyProvider == provider
            val dim = if (busy) 1f else 0.55f
            OutlinedButton(
                onClick = { onSelect(provider) },
                enabled = state.busyProvider == null,
                shape = CircleShape,
                border = BorderStroke(1.dp, SocialStroke),
                contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = MMInk.Card,
                    contentColor = MMInk.Text,
                    disabledContainerColor = MMInk.Card,
                    disabledContentColor = MMInk.Text.copy(alpha = dim),
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    // A minimum, not a fixed height: at large font scales the label wraps instead of being clipped (F29).
                    .heightIn(min = MMMetrics.CtaHeight)
                    .testTag("welcome.social.${provider.id}"),
            ) {
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = MMInk.Secondary)
                } else {
                    if (provider == SocialProvider.GOOGLE) {
                        Image(
                            painter = painterResource(R.drawable.ic_google_g),
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(10.dp))
                    }
                    Text(
                        provider.buttonTitle,
                        style = mmFont(15.5f, FontWeight.Medium),
                        color = MMInk.Text.copy(alpha = if (state.busyProvider == null) 1f else dim),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                }
            }
        }
        state.errorMessage?.let {
            Text(it, style = mmFont(13f), color = MMInk.Danger, modifier = Modifier.testTag("welcome.social.error"))
        }
    }
}
