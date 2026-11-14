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
import com.surensureshkumar.movemark.data.legal.LegalUnavailable

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
    deleting: Boolean = false,
    deleteError: String? = null,
) {
    var agreed by remember { mutableStateOf(false) }
    // A changed age statement needs fresh answers. Nothing is pre-selected. The Quebec answer lives only here, in screen
    // state: it is never stored, logged or sent (the server only ever receives "No", inside the acceptance call).
    var ageChoice by remember(state.ageRequirement) { mutableStateOf<LegalAgeChoice?>(null) }
    var livesInQuebec by remember(state.ageRequirement) { mutableStateOf<Boolean?>(null) }
    var ageConfirmed by remember(state.ageRequirement) { mutableStateOf(false) }
    val chosenBand = ageChoice?.band(livesInQuebec)
    val stop = legalStop(state, ageChoice, livesInQuebec)
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
                        livesInQuebec = if (state.regionRefused) true else livesInQuebec,
                        onChoice = { ageChoice = it },
                        onQuebec = { livesInQuebec = it; if (it) ageChoice = null },
                    )
                    state.asksSingleBox -> state.age?.let { age ->
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(
                                Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("legal.age")
                                    .toggleable(value = ageConfirmed, role = Role.Checkbox, onValueChange = { ageConfirmed = it }),
                                verticalAlignment = Alignment.Top,
                            ) {
                                Checkbox(
                                    checked = ageConfirmed,
                                    onCheckedChange = null,
                                    colors = CheckboxDefaults.colors(checkedColor = Ink, uncheckedColor = Ink),
                                )
                                Spacer(Modifier.width(12.dp))
                                Text(age.confirmation, color = Ink, fontSize = 15.sp)
                            }
                            Text(age.explanation, color = Quiet, fontSize = 13.sp)
                        }
                    }
                    state.requiresAppUpdate -> Notice(LegalGateViewModel.UPDATE_APP, tag = "legal.update")
                }
                (deleteError ?: state.error)?.let { Text(it, color = Color(0xFFBD3228), fontSize = 14.sp, modifier = Modifier.testTag("legal.error")) }
            }
        }
        Column(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (stop != null) {
                // Not available (Quebec, or under 13): nothing is sent, and deletion is offered, never automatic.
                PrimaryButton(if (deleting) "Deleting…" else "Delete my account", enabled = !state.isSaving && !deleting, tag = "legal.delete") { confirmDelete = true }
                TextButton(onClick = onSignOut, enabled = !state.isSaving && !deleting) { Text("Sign out", color = Quiet) }
            } else {
                val enabled = legalCanContinue(agreed, state, chosenBand, ageConfirmed)
                PrimaryButton(if (state.isSaving) "Saving…" else "Continue to my Vault", enabled = enabled && !deleting, tag = "legal.continue") {
                    onAccept(chosenBand)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    TextButton(onClick = onSignOut, enabled = !state.isSaving && !deleting) { Text("Sign out", color = Quiet) }
                    TextButton(onClick = { confirmDelete = true }, enabled = !state.isSaving && !deleting) {
                        Text(if (deleting) "Deleting…" else "Delete account", color = Quiet)
                    }
                }
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

internal const val CHILDRENS_PRIVACY_URL = "https://movemark.ca/privacy#childrens-privacy"

/** The consent line and the age notices, word for word as iOS 1.4. */
internal const val LEGAL_CONSENT_TEXT =
    "I agree to the Terms of Service and consent to MoveMark handling my information as the Privacy Policy describes."
internal const val LEGAL_ADULT_NOTICE =
    "MoveMark keeps what you add: photos of the rental, its address, notes and documents. It’s stored with our service providers in the United States and is never sold or used for ads. Original photos keep any location your phone saved in them. Only you can see your vault in the app; MoveMark staff access it only to run the service, give support or meet legal duties. Delete everything anytime in Account; backups take longer to clear."
internal const val LEGAL_TEEN_NOTICE =
    "Because you’re under 18, photos you add are saved without where they were taken or which phone took them. MoveMark keeps your photos, rental address, notes and documents with service providers in the United States. Only you can see them in the app; MoveMark staff access them only to run the service, give support or meet legal duties. Delete everything in Account; backups take longer to clear. Questions? Ask a parent or email connect@movemark.ca."

/** The terms, an eligible answer to a statement this build knows, and nothing in flight. */
internal fun legalCanContinue(
    agreed: Boolean,
    state: LegalGateState,
    band: LegalAgeBand?,
    ageConfirmed: Boolean = false,
): Boolean = when {
    !agreed || state.isSaving || state.requiresAppUpdate || state.regionRefused -> false
    state.asksAgeRange -> band != null
    state.asksSingleBox -> ageConfirmed
    else -> true
}

/** Why the screen stops here, if it does (range questions only). */
internal fun legalStop(state: LegalGateState, choice: LegalAgeChoice?, livesInQuebec: Boolean?): LegalUnavailable? = when {
    !state.asksAgeRange -> null
    state.regionRefused -> LegalUnavailable.Quebec
    else -> LegalUnavailable.reason(choice, livesInQuebec)
}

@Composable
private fun PrimaryButton(label: String, enabled: Boolean, tag: String, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().heightIn(min = 52.dp)
            .background(if (enabled) Lime else Lime.copy(alpha = 0.45f), RoundedCornerShape(26.dp))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, color = OnLime, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * "Do you live in Quebec?" first, for every age. "Yes" hides the age question and shows the Quebec stop. "No" asks the
 * age range: four plain answers, nothing pre-selected, no date of birth. Under 13 stops too. Nothing suggests changing
 * an answer.
 */
@Composable
private fun AgeRangeQuestion(
    choice: LegalAgeChoice?,
    livesInQuebec: Boolean?,
    onChoice: (LegalAgeChoice) -> Unit,
    onQuebec: (Boolean) -> Unit,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text("Do you live in Quebec?", color = Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Row(Modifier.selectableGroup(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            RadioRow("Yes", selected = livesInQuebec == true, tag = "legal.quebec.yes", fill = false) { onQuebec(true) }
            RadioRow("No", selected = livesInQuebec == false, tag = "legal.quebec.no", fill = false) { onQuebec(false) }
        }
        if (livesInQuebec == true) {
            Column(
                Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).padding(14.dp)
                    .testTag("legal.quebec.unavailable"),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(LegalUnavailable.QUEBEC_MESSAGE, color = Ink, fontSize = 14.sp)
                Text(LegalUnavailable.QUEBEC_SUBSCRIPTION_NOTE, color = Quiet, fontSize = 13.sp)
            }
            return@Column
        }
        if (livesInQuebec != false) return@Column
        Column(Modifier.fillMaxWidth().selectableGroup().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("How old are you?", color = Ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            LegalAgeChoice.entries.forEach { option ->
                RadioRow(option.label, selected = choice == option, tag = "legal.age.${option.name}") { onChoice(option) }
            }
        }
        when (choice?.band(livesInQuebec)) {
            LegalAgeBand.Teen -> Column {
                Text(LEGAL_TEEN_NOTICE, color = Quiet, fontSize = 13.sp, modifier = Modifier.testTag("legal.age.teenNotice"))
                val context = LocalContext.current
                Row(
                    Modifier.heightIn(min = 48.dp)
                        .clickable(role = Role.Button) { openInAppBrowser(context, CHILDRENS_PRIVACY_URL) }
                        .testTag("legal.age.childrensPrivacy"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Children’s privacy", color = Ink, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.width(4.dp))
                    Text("↗", color = Quiet, fontSize = 13.sp)
                }
            }
            LegalAgeBand.Adult -> Text(LEGAL_ADULT_NOTICE, color = Quiet, fontSize = 13.sp, modifier = Modifier.testTag("legal.age.adultNotice"))
            null -> if (choice == LegalAgeChoice.Under13) {
                Notice(LegalUnavailable.AGE_MESSAGE, tag = "legal.age.unavailable")
            } else {
                Text("MoveMark asks for your age range only, never your date of birth.", color = Quiet, fontSize = 13.sp)
            }
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

/** The server answered the legal status with an error (iOS `LegalStatusUnavailableView`): a retry and a way out. */
@Composable
fun LegalStatusUnavailableScreen(isRetrying: Boolean, onRetry: () -> Unit, onSignOut: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Sheet)) {
        Column(
            Modifier.fillMaxWidth().background(Hero).statusBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 32.dp, bottom = 40.dp),
        ) {
            Text("MoveMark", color = Color.White.copy(alpha = 0.62f), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.padding(top = 8.dp))
            Text(
                "Can’t open your Vault yet",
                color = Color.White,
                fontSize = 30.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { heading() },
            )
        }
        Text(
            "MoveMark couldn’t check your account just now. Your records are safe. Try again in a moment.",
            color = Ink,
            fontSize = 16.sp,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 22.dp).weight(1f),
        )
        Column(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            PrimaryButton(if (isRetrying) "Trying…" else "Try again", enabled = !isRetrying, tag = "legal.status.retry", onClick = onRetry)
            TextButton(onClick = onSignOut, enabled = !isRetrying) { Text("Sign out", color = Quiet) }
        }
    }
}
