package com.surensureshkumar.movemark.features.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard
import com.surensureshkumar.movemark.core.util.PlaySubscriptionIntents
import com.surensureshkumar.movemark.features.subscription.PaywallReason

@Composable
fun AccountScreen(
    onSignOut: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val email by viewModel.email.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val restoreMessage by viewModel.restoreMessage.collectAsState()
    val purchasing by viewModel.purchasing.collectAsState()
    val isMockMode = viewModel.isMockMode
    val context = LocalContext.current
    LaunchedEffect(Unit) { viewModel.refreshSubscription() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        Text("Account", style = androidx.compose.material3.MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(16.dp))
        MMProofCard {
            Text(email ?: "Signed in", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(6.dp))
            Text(
                if (hasPro) "MoveMark Pro" else "MoveMark Free",
                color = MMColors.TextPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 17.sp,
            )
            Text(
                if (hasPro) "Active" else "Current",
                color = if (hasPro) MMColors.Primary else MMColors.TextMuted,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
            )
            if (isMockMode && hasPro) {
                Spacer(Modifier.height(4.dp))
                Text("Test mode", color = MMColors.TextMuted, fontSize = 12.sp)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                if (hasPro) {
                    "Unlimited vaults, reports, move-out proof, and dispute tools."
                } else {
                    "1 property · 1 move-in report"
                },
                color = MMColors.TextSecondary,
                fontSize = 14.sp,
            )
        }
        Spacer(Modifier.height(12.dp))
        if (!hasPro) {
            MMButton(text = "Upgrade to Pro", onClick = { onShowPaywall(PaywallReason.ExtraProperty) })
            Spacer(Modifier.height(8.dp))
        } else if (!isMockMode) {
            MMButton(
                text = "Manage subscription",
                onClick = { PlaySubscriptionIntents.openManageSubscriptions(context) },
                style = MMButtonStyle.Secondary,
            )
            Spacer(Modifier.height(8.dp))
        }
        if (isMockMode) {
            MMButton(
                text = "Reset test subscription",
                onClick = viewModel::resetTestSubscription,
                style = MMButtonStyle.Secondary,
            )
            Spacer(Modifier.height(8.dp))
        }
        MMButton(
            text = if (purchasing) "Restoring…" else "Restore purchases",
            onClick = viewModel::restorePurchases,
            style = MMButtonStyle.Secondary,
            enabled = !purchasing,
            loading = purchasing,
        )
        restoreMessage?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MMColors.Primary, fontSize = 14.sp)
        }
        Spacer(Modifier.height(16.dp))
        TextButton(onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AccountViewModel.PRIVACY_URL)))
        }) { Text("Privacy Policy", color = MMColors.TextSecondary) }
        TextButton(onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AccountViewModel.TERMS_URL)))
        }) { Text("Terms of Use", color = MMColors.TextSecondary) }
        Spacer(Modifier.weight(1f))
        MMButton(text = "Sign out", onClick = { viewModel.signOut(onSignOut) }, style = MMButtonStyle.Secondary)
    }
}
