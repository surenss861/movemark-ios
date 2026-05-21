package com.surensureshkumar.movemark.features.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard

@Composable
fun AccountScreen(
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val email by viewModel.email.collectAsState()
    val context = LocalContext.current

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        Text("Account", style = androidx.compose.material3.MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(16.dp))
        MMProofCard {
            Text(email ?: "Signed in", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
            Text("MoveMark Free", color = MMColors.TextSecondary)
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
