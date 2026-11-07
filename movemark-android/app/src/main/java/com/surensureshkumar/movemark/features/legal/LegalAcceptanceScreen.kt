/**
 * @file One deliberate step between sign-in and the Vault, for new and existing renters. The box starts unchecked;
 *       declining keeps the documents, sign-out and account deletion in reach.
 * @domain onboarding-auth
 * @status wip
 * @see [[LegalAcceptanceScreen.swift]] — iOS counterpart
 */
package com.surensureshkumar.movemark.features.legal

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.ui.openInAppBrowser

private val Hero = Color(0xFF161817)
private val Sheet = Color(0xFFF8F8F8)
private val Ink = Color(0xFF141415)
private val Quiet = Color(0xFF7E7F80)
private val Stroke = Color(0xFFECECEC)
private val Lime = Color(0xFFCAE36C)
private val OnLime = Color(0xFF111608)

@Composable
fun LegalAcceptanceScreen(
    state: LegalGateState,
    onAccept: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
) {
    var agreed by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val terms = state.documents?.terms?.url ?: "https://movemark.ca/terms"
    val privacy = state.documents?.privacyNotice?.url ?: "https://movemark.ca/privacy"

    Column(Modifier.fillMaxSize().background(Sheet)) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()),
        ) {
            Column(
                Modifier.fillMaxWidth().background(Hero).statusBarsPadding()
                    .padding(start = 20.dp, end = 20.dp, top = 32.dp, bottom = 40.dp),
            ) {
                Text("MoveMark", color = Color.White.copy(alpha = 0.62f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.padding(top = 8.dp))
                Text(
                    "One last thing.",
                    color = Color.White,
                    fontSize = 34.sp,
                    lineHeight = 40.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.semantics { heading() },
                )
            }
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 22.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                Text(
                    "Before you start protecting your rental, please review and agree to our terms.",
                    color = Ink,
                    fontSize = 16.sp,
                )
                Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(14.dp))) {
                    DocumentRow("Terms of Service") { openInAppBrowser(context, terms) }
                    HorizontalDivider(color = Stroke)
                    DocumentRow("Privacy Policy") { openInAppBrowser(context, privacy) }
                }
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 48.dp)
                        .toggleable(value = agreed, role = Role.Checkbox, onValueChange = { agreed = it }),
                    verticalAlignment = Alignment.Top,
                ) {
                    Checkbox(
                        checked = agreed,
                        onCheckedChange = null,
                        colors = CheckboxDefaults.colors(checkedColor = Ink, uncheckedColor = Ink),
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "I agree to the Terms of Service and acknowledge the Privacy Policy.",
                        color = Ink,
                        fontSize = 15.sp,
                    )
                }
                state.error?.let { Text(it, color = Color(0xFFBD3228), fontSize = 14.sp) }
            }
        }
        Column(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val enabled = agreed && !state.isSaving
            Box(
                Modifier.fillMaxWidth().heightIn(min = 52.dp)
                    .background(if (enabled) Lime else Lime.copy(alpha = 0.45f), RoundedCornerShape(26.dp))
                    .clickable(enabled = enabled, role = Role.Button, onClick = onAccept),
                contentAlignment = Alignment.Center,
            ) {
                Text(if (state.isSaving) "Saving…" else "Continue to my Vault", color = OnLime, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TextButton(onClick = onSignOut, enabled = !state.isSaving) { Text("Sign out", color = Quiet) }
                TextButton(onClick = { confirmDelete = true }, enabled = !state.isSaving) { Text("Delete account", color = Quiet) }
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete your account?") },
            text = {
                Text("This deletes your account and the records in it. Encrypted backup copies last longer. An active subscription keeps billing until you cancel it in Google Play.")
            },
            confirmButton = {
                TextButton(onClick = { confirmDelete = false; onDeleteAccount() }) { Text("Delete account") }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Keep account") } },
        )
    }
}

@Composable
private fun DocumentRow(title: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(title, color = Ink, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Text("↗", color = Quiet, fontSize = 16.sp)
    }
}
