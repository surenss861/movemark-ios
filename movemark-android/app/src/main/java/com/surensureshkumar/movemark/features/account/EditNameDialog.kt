package com.surensureshkumar.movemark.features.account

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun EditNameDialog(
    currentName: String,
    saving: Boolean,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var name by remember(currentName) { mutableStateOf(currentName) }
    val trimmed = name.trim()
    val canSave = trimmed.isNotEmpty() && trimmed != currentName.trim() && !saving

    AlertDialog(
        onDismissRequest = { if (!saving) onDismiss() },
        title = { Text("Edit name") },
        text = {
            Column {
                MMTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = "Full name",
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Your name appears on proof records.",
                    color = MMColors.TextMuted,
                    style = androidx.compose.material3.MaterialTheme.typography.bodySmall,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(trimmed) }, enabled = canSave) {
                Text(if (saving) "Saving…" else "Save", color = MMColors.Primary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !saving) {
                Text("Cancel", color = MMColors.TextSecondary)
            }
        },
    )
}
