package com.surensureshkumar.movemark.features.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMSettingsAccessory
import com.surensureshkumar.movemark.core.design.components.MMSettingsDivider
import com.surensureshkumar.movemark.core.design.components.MMSettingsGroup
import com.surensureshkumar.movemark.core.design.components.MMSettingsRow
import com.surensureshkumar.movemark.core.design.components.MMSettingsSectionHeader
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
    val fullName by viewModel.fullName.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val restoreMessage by viewModel.restoreMessage.collectAsState()
    val purchasing by viewModel.purchasing.collectAsState()
    val resetInProgress by viewModel.resetInProgress.collectAsState()
    val profileSaving by viewModel.profileSaving.collectAsState()
    val notice by viewModel.notice.collectAsState()
    val isMockMode = viewModel.isMockMode
    val context = LocalContext.current
    val reduceMotion = MMMotion.rememberReduceMotion()
    var appeared by remember { mutableStateOf(reduceMotion) }
    var showEditName by remember { mutableStateOf(false) }

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) appeared = true
    }
    LaunchedEffect(Unit) { viewModel.refresh() }

    val displayName = fullName?.takeIf { it.isNotBlank() } ?: "Add your name"
    val displayEmail = email?.takeIf { it.isNotBlank() } ?: "—"
    val planFooter = when {
        hasPro && isMockMode ->
            "Test mode · Unlimited vaults, reports, move-out proof, and dispute tools."
        hasPro -> "Unlimited vaults, reports, move-out proof, and dispute tools."
        isMockMode -> "Test mode · 1 proof vault · 1 move-in report"
        else -> "1 proof vault · 1 move-in report"
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

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            .padding(top = 12.dp, bottom = MMSpacing.TabScrollBottom.dp),
    ) {
        MMProofSectionHeader(
            title = "Account",
            subtitle = "Manage your profile, plan, and proof vaults.",
            modifier = Modifier.mmAppearRise(appeared, reduceMotion, label = "accountHeader"),
        )
        Spacer(Modifier.height(22.dp))

        AccountNoticeBanner(notice)
        restoreMessage?.let {
            Spacer(Modifier.height(8.dp))
            AccountInlineMessage(it, isError = false)
        }

        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "profile")) {
            MMSettingsSectionHeader(title = "Profile")
            MMSettingsGroup {
                MMSettingsRow(
                    title = "Name",
                    value = displayName,
                    accessory = MMSettingsAccessory.None,
                    onClick = null,
                )
                MMSettingsDivider()
                MMSettingsRow(
                    title = "Email",
                    value = displayEmail,
                    accessory = MMSettingsAccessory.None,
                    onClick = null,
                )
                MMSettingsDivider()
                MMSettingsRow(
                    title = "Edit name",
                    subtitle = "Update how your name appears",
                    onClick = { showEditName = true },
                )
            }
        }

        Spacer(Modifier.height(22.dp))
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "plan")) {
            MMSettingsSectionHeader(title = "Plan", footer = planFooter)
            MMSettingsGroup {
                MMSettingsRow(
                    title = if (hasPro) "MoveMark Pro" else "MoveMark Free",
                    pillText = if (hasPro) "Active" else "Current",
                    pillIsActive = hasPro,
                    onClick = null,
                )
                if (!hasPro) {
                    MMSettingsDivider()
                    MMSettingsRow(
                        title = "Upgrade to Pro",
                        subtitle = "Unlimited vaults, reports, and dispute tools",
                        onClick = {
                            viewModel.dismissNotice()
                            onShowPaywall(PaywallReason.ExtraProperty)
                        },
                    )
                    if (isMockMode) {
                        MMSettingsDivider()
                        MMSettingsRow(
                            title = "Unlock Pro for testing",
                            subtitle = "Mock purchase — no Play Console required",
                            onClick = {
                                viewModel.dismissNotice()
                                onShowPaywall(PaywallReason.ExtraProperty)
                            },
                        )
                    }
                }
                if (hasPro && !isMockMode) {
                    MMSettingsDivider()
                    MMSettingsRow(
                        title = "Manage subscription",
                        subtitle = "Google Play subscriptions",
                        accessory = MMSettingsAccessory.External,
                        onClick = { PlaySubscriptionIntents.openManageSubscriptions(context) },
                    )
                }
                if (isMockMode && hasPro) {
                    MMSettingsDivider()
                    MMSettingsRow(
                        title = "Reset test subscription",
                        subtitle = "Clear mock Pro for local QA",
                        onClick = viewModel::resetTestSubscription,
                    )
                }
                if (isMockMode && !hasPro) {
                    MMSettingsDivider()
                    MMSettingsRow(
                        title = "Test mode",
                        subtitle = "Mock billing is active in this build",
                        accessory = MMSettingsAccessory.None,
                        onClick = null,
                    )
                }
                MMSettingsDivider()
                MMSettingsRow(
                    title = if (purchasing) "Restoring purchases…" else "Restore purchases",
                    subtitle = "Sync MoveMark Pro with this account",
                    enabled = !purchasing,
                    onClick = viewModel::restorePurchases,
                )
            }
        }

        Spacer(Modifier.height(22.dp))
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "privacy")) {
            MMSettingsSectionHeader(title = "Privacy & support")
            MMSettingsGroup {
                LegalLinkRow("Privacy Policy", "How we handle your data") {
                    openUrl(context, AccountViewModel.PRIVACY_URL)
                }
                MMSettingsDivider()
                LegalLinkRow("Terms of Use", "Subscription and service terms") {
                    openUrl(context, AccountViewModel.TERMS_URL)
                }
                MMSettingsDivider()
                LegalLinkRow("Contact Support", "Get help with your account") {
                    openUrl(context, AccountViewModel.SUPPORT_URL)
                }
                MMSettingsDivider()
                LegalLinkRow("Account & Data Deletion", "Request account removal") {
                    openUrl(context, AccountViewModel.ACCOUNT_DELETION_URL)
                }
            }
        }

        Spacer(Modifier.height(22.dp))
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "security")) {
            MMSettingsSectionHeader(title = "Security")
            MMSettingsGroup {
                MMSettingsRow(
                    title = "Reset password",
                    subtitle = "Send a link to your email",
                    value = if (resetInProgress) "Sending…" else null,
                    enabled = !resetInProgress,
                    onClick = viewModel::sendPasswordReset,
                )
            }
        }

        Spacer(Modifier.height(22.dp))
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "about")) {
            MMSettingsSectionHeader(title = "About")
            MMSettingsGroup {
                MMSettingsRow(
                    title = "App version",
                    value = viewModel.appVersion,
                    accessory = MMSettingsAccessory.None,
                    onClick = null,
                )
                if (isMockMode) {
                    MMSettingsDivider()
                    MMSettingsRow(
                        title = "Billing mode",
                        value = "Mock (local QA)",
                        accessory = MMSettingsAccessory.None,
                        onClick = null,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "MoveMark helps renters document proof and records. It does not provide legal advice.",
                fontSize = 13.sp,
                color = MMColors.TextMuted,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }

        Spacer(Modifier.height(28.dp))
        MMSettingsGroup(
            modifier = Modifier.mmAppearRise(appeared, reduceMotion, label = "signOut"),
        ) {
            MMSettingsRow(
                title = "Sign out",
                subtitle = "Clear this device and return to Welcome",
                onClick = { viewModel.signOut(onSignOut) },
            )
        }
    }
}

@Composable
private fun LegalLinkRow(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    MMSettingsRow(
        title = title,
        subtitle = subtitle,
        accessory = MMSettingsAccessory.External,
        onClick = onClick,
    )
}

@Composable
private fun AccountNoticeBanner(notice: AccountNotice?) {
    notice ?: return
    Spacer(Modifier.height(4.dp))
    AccountInlineMessage(notice.message, isError = notice.isError)
}

@Composable
private fun AccountInlineMessage(message: String, isError: Boolean) {
    Text(
        message,
        color = if (isError) MMColors.SemanticDanger else MMColors.TextSecondary,
        fontSize = 13.sp,
        modifier = Modifier.padding(horizontal = 4.dp),
    )
}

private fun openUrl(context: android.content.Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
