package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.core.util.MMUserMessages
import kotlinx.coroutines.launch

/**
 * Set a new password from a `movemark://reset-password` link (iOS `PasswordResetView`): the same surface as sign
 * in, reachable only from the link itself.
 */
@Composable
fun PasswordResetScreen(
    onReset: suspend (password: String, confirm: String) -> Unit,
    onDone: () -> Unit,
) {
    var password by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    var didReset by rememberSaveable { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Dialog(
        onDismissRequest = { if (!saving) onDone() },
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false),
    ) {
        MMBackground {
            Column(
                Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 12.dp),
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    if (!didReset) {
                        IconButton(onClick = onDone, enabled = !saving) {
                            Icon(Icons.Filled.Close, contentDescription = "Cancel", tint = MMColors.TextPrimary)
                        }
                    } else {
                        Spacer(Modifier.height(48.dp))
                    }
                }
                Text(
                    if (didReset) "Password updated" else "Choose a new password",
                    color = MMColors.TextPrimary,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    if (didReset) "Sign in with your new password." else "Use at least 8 characters.",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                )
                Spacer(Modifier.height(24.dp))
                if (didReset) {
                    MMButton(text = "Done", onClick = onDone)
                } else {
                    MMTextField(value = password, onValueChange = { password = it }, label = "New password", isPassword = true)
                    Spacer(Modifier.height(14.dp))
                    MMTextField(value = confirm, onValueChange = { confirm = it }, label = "Confirm password", isPassword = true)
                    error?.let {
                        Spacer(Modifier.height(16.dp))
                        Box(Modifier.semantics { liveRegion = LiveRegionMode.Polite }) {
                            Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
                        }
                    }
                    Spacer(Modifier.height(22.dp))
                    MMButton(
                        text = "Save new password",
                        loading = saving,
                        enabled = !saving,
                        onClick = {
                            saving = true
                            error = null
                            scope.launch {
                                try {
                                    onReset(password, confirm)
                                    didReset = true
                                } catch (e: Exception) {
                                    error = e.message?.takeUnless { MMUserMessages.isTechnical(it) }
                                        ?: "Couldn’t reset your password. Try again."
                                } finally {
                                    saving = false
                                }
                            }
                        },
                    )
                }
            }
        }
    }
}
