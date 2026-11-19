package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.surensureshkumar.movemark.core.design.MMInk
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.core.util.MMUserMessages
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.io.IOException

/**
 * Set a new password from a `movemark://reset-password` link (iOS `PasswordResetView`): the same surface as sign
 * in, reachable only from the link itself.
 *
 * A link Neon Auth already judged dead ([linkExpired], `error=` in the URL) or a token it refuses on save
 * ([PasswordResetRequest.isRejectedToken]) shows "Link expired"; a network failure stays on the form.
 *
 * @param onDone closes the screen.
 * @param onSignIn the done state's "Sign in" (iOS `onDone(.signIn)`); defaults to closing.
 * @param onRequestNewLink the expired state's "Request a new link" (iOS `onDone(.resetPassword)`); defaults to closing.
 * @param signedIn a signed-in person gets "Done" on the expired state instead of a new link (iOS `expiredContent`).
 */
@Composable
fun PasswordResetScreen(
    onReset: suspend (password: String, confirm: String) -> Unit,
    onDone: () -> Unit,
    linkExpired: Boolean = false,
    signedIn: Boolean = false,
    onSignIn: () -> Unit = onDone,
    onRequestNewLink: () -> Unit = onDone,
) {
    var saving by remember { mutableStateOf(false) }
    Dialog(
        onDismissRequest = { if (!saving) onDone() },
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false),
    ) {
        PasswordResetContent(
            onReset = onReset,
            onDone = onDone,
            linkExpired = linkExpired,
            signedIn = signedIn,
            onSignIn = onSignIn,
            onRequestNewLink = onRequestNewLink,
            onSavingChange = { saving = it },
        )
    }
}

/** The reset surface without its dialog window (tested directly). */
@Composable
internal fun PasswordResetContent(
    onReset: suspend (password: String, confirm: String) -> Unit,
    onDone: () -> Unit,
    linkExpired: Boolean = false,
    signedIn: Boolean = false,
    onSignIn: () -> Unit = onDone,
    onRequestNewLink: () -> Unit = onDone,
    onSavingChange: (Boolean) -> Unit = {},
) {
    var password by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    var didReset by rememberSaveable { mutableStateOf(false) }
    // Neon Auth rejected the token (expired, used, or malformed): saving again can't work.
    var tokenRejected by rememberSaveable(linkExpired) { mutableStateOf(linkExpired) }
    val scope = rememberCoroutineScope()

    MMScreen(
        title = when {
            didReset -> "Password updated"
            tokenRejected -> "Link expired"
            else -> "Choose a new password"
        },
        lines = listOf(
            when {
                didReset -> "Sign in with your new password."
                tokenRejected -> "Reset links work once and expire soon after they’re sent."
                else -> "Use at least 8 characters."
            },
        ),
        showsWordmark = true,
        modifier = Modifier.imePadding(),
        trailing = {
            if (!didReset) {
                IconButton(
                    onClick = onDone,
                    enabled = !saving,
                    modifier = Modifier.testTag("passwordReset.cancel"),
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Cancel", tint = MMInk.HeroText)
                }
            }
        },
    ) {
        when {
            // The reset signs this device out (SessionManager), so the next step is always signing in.
            didReset -> MMPrimaryButton(
                title = "Sign in",
                onClick = onSignIn,
                modifier = Modifier.testTag("passwordReset.done"),
            )
            tokenRejected -> {
                MMNotice(PasswordResetRequest.EXPIRED_LINK_MESSAGE, modifier = Modifier.testTag("passwordReset.expired"))
                Spacer(Modifier.height(22.dp))
                // A signed-out person goes straight to asking for a new link; a signed-in one just closes.
                if (signedIn) {
                    MMPrimaryButton(title = "Done", onClick = onDone, modifier = Modifier.testTag("passwordReset.close"))
                } else {
                    MMPrimaryButton(
                        title = "Request a new link",
                        onClick = onRequestNewLink,
                        modifier = Modifier.testTag("passwordReset.requestNew"),
                    )
                }
            }
            else -> {
                MMTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = "New password",
                    modifier = Modifier.testTag("passwordReset.password"),
                    isPassword = true,
                    onLight = true,
                    placeholder = "At least 8 characters",
                )
                Spacer(Modifier.height(14.dp))
                MMTextField(
                    value = confirm,
                    onValueChange = { confirm = it },
                    label = "Confirm password",
                    modifier = Modifier.testTag("passwordReset.confirm"),
                    isPassword = true,
                    onLight = true,
                    placeholder = "Same as above",
                )
                error?.let {
                    Spacer(Modifier.height(18.dp))
                    Box(Modifier.semantics { liveRegion = LiveRegionMode.Polite }) {
                        MMNotice(it, modifier = Modifier.testTag("passwordReset.error"))
                    }
                }
                Spacer(Modifier.height(22.dp))
                MMPrimaryButton(
                    title = "Save new password",
                    isLoading = saving,
                    enabled = !saving,
                    modifier = Modifier.testTag("passwordReset.save"),
                    onClick = {
                        saving = true
                        onSavingChange(true)
                        error = null
                        scope.launch {
                            try {
                                onReset(password, confirm)
                                didReset = true
                            } catch (e: CancellationException) {
                                throw e
                            } catch (e: Exception) {
                                if (PasswordResetRequest.isRejectedToken(e)) {
                                    tokenRejected = true
                                } else {
                                    error = resetFailureMessage(e)
                                }
                            } finally {
                                saving = false
                                onSavingChange(false)
                            }
                        }
                    },
                )
            }
        }
    }
}

/** What a failed save says when the token itself was not refused. Never "expired": that is only for token codes. */
internal fun resetFailureMessage(error: Throwable): String = when (error) {
    is IOException -> PasswordResetRequest.NO_CONNECTION
    else -> error.message?.takeUnless { it.isBlank() || MMUserMessages.isTechnical(it) }
        ?: "Couldn’t reset your password. Try again."
}
