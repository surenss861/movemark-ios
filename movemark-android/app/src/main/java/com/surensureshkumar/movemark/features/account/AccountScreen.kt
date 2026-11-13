package com.surensureshkumar.movemark.features.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMNoticeTone
import com.surensureshkumar.movemark.core.design.MMRow
import com.surensureshkumar.movemark.core.design.MMRowAccessory
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmLines
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.util.PlaySubscriptionIntents
import com.surensureshkumar.movemark.features.subscription.PaywallReason

@Composable
fun AccountScreen(
    onSignOut: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    scrollState: androidx.compose.foundation.ScrollState = androidx.compose.foundation.rememberScrollState(),
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val email by viewModel.email.collectAsState()
    val fullName by viewModel.fullName.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val restoreMessage by viewModel.restoreMessage.collectAsState()
    val purchasing by viewModel.purchasing.collectAsState()
    val resetInProgress by viewModel.resetInProgress.collectAsState()
    val profileSaving by viewModel.profileSaving.collectAsState()
    val notice by viewModel.notice.collectAsState()
    val deleting by viewModel.deleting.collectAsState()
    var confirmDelete by remember { mutableStateOf(false) }
    val isMockMode = viewModel.isMockMode
    val context = LocalContext.current
    var showEditName by remember { mutableStateOf(false) }
    var unsavedOnSignOut by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { viewModel.refresh() }

    val planLine = when {
        hasPro && isMockMode -> "MoveMark Pro · Test mode"
        hasPro -> "MoveMark Pro"
        isMockMode -> "Free plan · Test mode"
        else -> "Free plan"
    }

    if (showEditName) {
        EditNameDialog(
            currentName = fullName.orEmpty(),
            saving = profileSaving,
            onDismiss = { showEditName = false },
            onSave = { name ->
                viewModel.updateFullName(name)
                showEditName = false
            },
        )
    }

    MMScreen(
        title = "Your account",
        eyebrow = "Account",
        tail = MMMetrics.RootTabTail,
        scrollState = scrollState,
        modifier = modifier,
    ) {
        // Who is signed in, and on which plan. Plain text on the sheet: not a card.
        Column(
            Modifier
                .padding(horizontal = 4.dp)
                .semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                email?.takeIf { it.isNotBlank() } ?: "Signed in",
                style = mmFont(19f, FontWeight.SemiBold),
                color = MMInk.Text,
                maxLines = mmLines(1),
                overflow = TextOverflow.Ellipsis,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (hasPro) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(MMInk.LimeMark))
                    Spacer(Modifier.width(7.dp))
                }
                Text(
                    planLine,
                    style = mmFont(14.5f, if (hasPro) FontWeight.Medium else FontWeight.Normal),
                    color = if (hasPro) MMInk.Text else MMInk.Secondary,
                )
            }
        }

        notice?.let {
            Spacer(Modifier.height(16.dp))
            MMNotice(it.message, tone = if (it.isError) MMNoticeTone.Error else MMNoticeTone.Info)
        }

        Spacer(Modifier.height(26.dp))
        MMGroup(
            title = "MoveMark",
            footer = restoreMessage,
        ) {
            MMRow(
                title = "Name",
                value = fullName?.takeIf { it.isNotBlank() } ?: "Add",
                onClick = { showEditName = true },
            )
            MMRowDivider()
            MMRow(
                title = "Subscription",
                value = if (hasPro) "Pro" else "Free",
                accessory = if (hasPro && !isMockMode) MMRowAccessory.External else MMRowAccessory.Chevron,
                onClick = {
                    if (hasPro) {
                        if (!isMockMode) PlaySubscriptionIntents.openManageSubscriptions(context)
                    } else {
                        viewModel.dismissNotice()
                        onShowPaywall(PaywallReason.ExtraProperty)
                    }
                },
            )
            if (isMockMode && hasPro) {
                MMRowDivider()
                MMRow(title = "Reset test subscription", subtitle = "Clear mock Pro for local QA", onClick = viewModel::resetTestSubscription)
            }
            if (isMockMode && !hasPro) {
                MMRowDivider()
                MMRow(title = "Test mode", subtitle = "Mock billing is active in this build", accessory = MMRowAccessory.None)
            }
            MMRowDivider()
            MMRow(
                title = if (purchasing) "Restoring purchases…" else "Restore purchases",
                enabled = !purchasing,
                accessory = MMRowAccessory.None,
                trailing = if (purchasing) ({ CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(16.dp)) }) else null,
                onClick = viewModel::restorePurchases,
            )
        }

        Spacer(Modifier.height(26.dp))
        MMGroup(title = "Support") {
            MMRow(title = "Contact support", accessory = MMRowAccessory.External, onClick = { openUrl(context, AccountViewModel.SUPPORT_URL) })
        }

        Spacer(Modifier.height(26.dp))
        MMGroup(title = "Legal") {
            MMRow(title = "Privacy Policy", accessory = MMRowAccessory.External, onClick = { openUrl(context, AccountViewModel.PRIVACY_URL) })
            MMRowDivider()
            MMRow(title = "Terms of Use", accessory = MMRowAccessory.External, onClick = { openUrl(context, AccountViewModel.TERMS_URL) })
            MMRowDivider()
            MMRow(
                title = "Account & data deletion",
                accessory = MMRowAccessory.External,
                onClick = { openUrl(context, AccountViewModel.ACCOUNT_DELETION_URL) },
            )
        }

        Spacer(Modifier.height(26.dp))
        MMGroup(title = "Security") {
            MMRow(
                title = "Reset password",
                subtitle = "Send a link to your email",
                value = if (resetInProgress) "Sending…" else null,
                enabled = !resetInProgress,
                onClick = viewModel::sendPasswordReset,
            )
        }

        Spacer(Modifier.height(34.dp))
        MMGroup {
            MMRow(
                title = "Sign out",
                accessory = MMRowAccessory.None,
                onClick = {
                    scope.launch {
                        val unsaved = viewModel.unsavedPhotoCount()
                        if (unsaved > 0) unsavedOnSignOut = unsaved else viewModel.signOut(onSignOut)
                    }
                },
            )
        }

        Spacer(Modifier.height(34.dp))
        MMGroup(footer = "Deletes your account, proof, reports and stored evidence.") {
            MMRow(
                title = if (deleting) "Deleting account…" else "Delete account",
                tint = MMInk.Danger,
                accessory = MMRowAccessory.None,
                enabled = !deleting,
                onClick = { confirmDelete = true },
            )
        }

        Spacer(Modifier.height(30.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text("MoveMark ${viewModel.appVersion}", style = mmFont(12f), color = MMInk.Secondary, textAlign = TextAlign.Center)
            Text(
                "MoveMark organizes rental evidence. It does not provide legal advice.",
                style = mmFont(12f),
                color = MMInk.Secondary,
                textAlign = TextAlign.Center,
            )
        }
    }

    if (unsavedOnSignOut > 0) {
        val count = unsavedOnSignOut
        AlertDialog(
            onDismissRequest = { unsavedOnSignOut = 0 },
            title = {
                Text(
                    if (count == 1) "1 photo hasn’t been saved yet. Signing out removes it from this phone."
                    else "$count photos haven’t been saved yet. Signing out removes them from this phone.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    unsavedOnSignOut = 0
                    viewModel.signOut(onSignOut)
                }) { Text("Sign out", color = MMInk.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { unsavedOnSignOut = 0 }) { Text("Cancel", color = MMInk.Secondary) }
            },
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete your account?") },
            text = {
                Column {
                    Text(
                        "This deletes your account, rentals, photos, records and reports. Encrypted backup copies last longer. An active subscription keeps billing until you cancel it in Google Play. It can’t be undone.",
                    )
                    // As iOS's delete screen: a way to cancel the store subscription before the account goes.
                    TextButton(onClick = { PlaySubscriptionIntents.openManageSubscriptions(context) }) {
                        Text("Manage Google Play subscription", color = MMInk.Secondary)
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    viewModel.deleteAccount(onSignOut)
                }) { Text("Delete", color = MMInk.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel", color = MMInk.Secondary) }
            },
        )
    }
}

private fun openUrl(context: android.content.Context, url: String) {
    if (url.startsWith("https://movemark.ca/")) {
        com.surensureshkumar.movemark.core.ui.openInAppBrowser(context, url)
        return
    }
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
