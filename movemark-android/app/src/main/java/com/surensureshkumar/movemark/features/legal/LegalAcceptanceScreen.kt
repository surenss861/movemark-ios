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
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.ui.openInAppBrowser
import com.surensureshkumar.movemark.data.legal.LegalAgeBand
import com.surensureshkumar.movemark.data.legal.LegalAgeChoice

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
    onAccept: (LegalAgeBand?) -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
) {
    var agreed by remember { mutableStateOf(false) }
    // A changed age statement needs a fresh answer. Nothing is pre-selected.
    var ageChoice by remember(state.ageRequirement) { mutableStateOf<LegalAgeChoice?>(null) }
    var livesInQuebec by remember(state.ageRequirement) { mutableStateOf<Boolean?>(null) }
    val chosenBand = ageChoice?.band(livesInQuebec)
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
                        LEGAL_CONSENT_TEXT,
                        color = Ink,
                        fontSize = 15.sp,
                    )
                }
                when {
                    state.asksAgeRange -> AgeRangeQuestion(
                        choice = ageChoice,
                        livesInQuebec = livesInQuebec,
                        onChoice = { choice ->
                            ageChoice = choice
                            if (choice != LegalAgeChoice.Thirteen) livesInQuebec = null
                        },
                        onQuebec = { livesInQuebec = it },
                    )
                    state.requiresAppUpdate -> Notice(LegalGateViewModel.UPDATE_APP)
                }
                state.error?.let { Text(it, color = Color(0xFFBD3228), fontSize = 14.sp) }
            }
        }
        Column(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val enabled = legalCanContinue(agreed, state, chosenBand)
            Box(
                Modifier.fillMaxWidth().heightIn(min = 52.dp)
                    .background(if (enabled) Lime else Lime.copy(alpha = 0.45f), RoundedCornerShape(26.dp))
                    .clickable(enabled = enabled, role = Role.Button, onClick = { onAccept(chosenBand) }),
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

/** The consent line and the age notices, word for word as iOS 1.4. */
internal const val LEGAL_CONSENT_TEXT =
    "I agree to the Terms of Service and consent to MoveMark handling my information as the Privacy Policy describes."
internal const val LEGAL_ADULT_NOTICE =
    "MoveMark keeps what you add: photos of the rental, its address, notes and documents. It’s stored with our service providers in the United States and is never sold or used for ads. Original photos keep any location your phone saved in them. Only you can see your vault in the app; MoveMark staff access it only to run the service, give support or meet legal duties. Delete everything anytime in Account; backups take longer to clear."
internal const val LEGAL_TEEN_NOTICE =
    "Because you’re under 18, photos you add are saved without where they were taken or which phone took them. MoveMark keeps your photos, rental address, notes and documents with service providers in the United States. Only you can see them in the app; MoveMark staff access them only to run the service, give support or meet legal duties. Delete everything in Account; backups take longer to clear. Questions? Ask a parent or email connect@movemark.ca."

/** Both answers given, an age statement this build knows, and nothing in flight. */
internal fun legalCanContinue(agreed: Boolean, state: LegalGateState, band: LegalAgeBand?): Boolean = when {
    !agreed || state.isSaving || state.requiresAppUpdate -> false
    state.asksAgeRange -> band != null
    else -> true
}

/**
 * One question, four plain answers, nothing pre-selected, no date of birth. Under 13, and 13 in Quebec, get a clear
 * "not available yet" with sign-out and deletion below; nothing suggests changing the answer.
 */
@Composable
private fun AgeRangeQuestion(
    choice: LegalAgeChoice?,
    livesInQuebec: Boolean?,
    onChoice: (LegalAgeChoice) -> Unit,
    onQuebec: (Boolean) -> Unit,
) {
    Column(Modifier.fillMaxWidth().selectableGroup(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text("How old are you?", color = Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        LegalAgeChoice.entries.forEach { option ->
            RadioRow(option.label, selected = choice == option, tag = "legal.age.${option.name}") { onChoice(option) }
        }
        if (choice == LegalAgeChoice.Thirteen) {
            Text(
                "Do you live in Quebec?",
                color = Ink,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp),
            )
            Row(Modifier.selectableGroup(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                RadioRow("Yes", selected = livesInQuebec == true, tag = "legal.age.quebec.yes", fill = false) { onQuebec(true) }
                RadioRow("No", selected = livesInQuebec == false, tag = "legal.age.quebec.no", fill = false) { onQuebec(false) }
            }
        }
        val band = choice?.band(livesInQuebec)
        when {
            choice != null && choice.isUnavailable(livesInQuebec) -> Notice(
                "MoveMark isn’t available for you yet. We’re working on a way for a parent or guardian to set it up with you. You can sign out or delete this account below.",
                tag = "legal.age.unavailable",
            )
            band == LegalAgeBand.Teen -> Text(
                LEGAL_TEEN_NOTICE,
                color = Quiet,
                fontSize = 13.sp,
                modifier = Modifier.testTag("legal.age.teenNotice"),
            )
            band == LegalAgeBand.Adult -> Text(
                LEGAL_ADULT_NOTICE,
                color = Quiet,
                fontSize = 13.sp,
                modifier = Modifier.testTag("legal.age.adultNotice"),
            )
            else -> Text("MoveMark asks for your age range only, never your date of birth.", color = Quiet, fontSize = 13.sp)
        }
    }
}

@Composable
private fun RadioRow(label: String, selected: Boolean, tag: String, fill: Boolean = true, onClick: () -> Unit) {
    Row(
        (if (fill) Modifier.fillMaxWidth() else Modifier).heightIn(min = 48.dp)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = Ink, unselectedColor = Ink))
        Spacer(Modifier.width(12.dp))
        Text(label, color = Ink, fontSize = 15.sp)
    }
}

@Composable
private fun Notice(message: String, tag: String? = null) {
    Text(
        message,
        color = Ink,
        fontSize = 14.sp,
        modifier = Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).padding(14.dp)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier),
    )
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
