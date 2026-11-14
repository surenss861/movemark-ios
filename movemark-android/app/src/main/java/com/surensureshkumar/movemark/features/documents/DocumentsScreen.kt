package com.surensureshkumar.movemark.features.documents

import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.graphics.Color
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import android.content.Intent
import androidx.core.content.FileProvider
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.Icons
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.domain.VaultDocumentKind

@Composable
fun DocumentsScreen(
    onBack: () -> Unit,
    onEditRental: () -> Unit = {},
    viewModel: DocumentsViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val documents by viewModel.documents.collectAsState()
    val error by viewModel.error.collectAsState()
    val uploading by viewModel.uploading.collectAsState()
    val deleting by viewModel.deleting.collectAsState()
    var confirmDelete by remember { mutableStateOf<VaultDocumentKind?>(null) }
    var showAll by remember { mutableStateOf(false) }
    var pendingKind by remember { mutableStateOf<VaultDocumentKind?>(null) }
    // The system file picker delivers its result together with a back event. Without this,
    // that back pops Documents and cancels the upload before the row is saved.
    var holdBack by remember { mutableStateOf(false) }
    var holdToken by remember { mutableIntStateOf(0) }
    BackHandler(enabled = holdBack) {}
    LaunchedEffect(holdToken) {
        if (holdToken == 0) return@LaunchedEffect
        delay(800)
        holdBack = false
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val kind = pendingKind
        pendingKind = null
        holdToken += 1
        if (uri == null || kind == null) return@rememberLauncherForActivityResult
        val name = displayName(context, uri)
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        if (bytes == null) return@rememberLauncherForActivityResult
        viewModel.upload(kind, bytes, name)
    }

    LaunchedEffect(Unit) { viewModel.refresh() }
    LaunchedEffect(Unit) {
        viewModel.openFile.collect { (file, mimeType) ->
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            runCatching { context.startActivity(intent) }
        }
    }

    val types = documents.map { it.documentType }
    val uploaded = VaultDocumentKind.supportingRecordCount(types)
    val visible = if (showAll) {
        VaultDocumentKind.all
    } else {
        VaultDocumentKind.priority.filter { !VaultDocumentKind.isPresent(it, types) }
    }

    // 1.4 grammar (iOS records screen in MMScreen): header with back and Edit rental, the records as one light group.
    MMScreen(
        title = "Receipts & lease docs",
        eyebrow = "Records",
        lines = listOf("Lease, deposit receipt, and other papers.", "$uploaded of ${VaultDocumentKind.all.size} uploaded"),
        onBack = onBack,
        trailing = {
            TextButton(onClick = onEditRental, modifier = Modifier.heightIn(min = 48.dp)) {
                Text("Edit rental", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        },
    ) {
        error?.let {
            Text(it, color = MMInk.Danger, fontSize = 14.sp)
            Spacer(Modifier.height(12.dp))
        }
        // Collapsed, this lists only missing priority records (as on iOS); with all three on
        // file there is nothing to list, so no empty group — just "See all records".
        if (visible.isNotEmpty()) MMGroup {
            visible.forEachIndexed { index, kind ->
                val present = VaultDocumentKind.isPresent(kind, types)
                if (index > 0) MMRowDivider()
                DocumentRow(
                    kind = kind,
                    present = present,
                    busy = uploading == kind || deleting == kind,
                    expanded = showAll,
                    onUpload = {
                        pendingKind = kind
                        holdBack = true
                        val mime = if (kind.acceptsImage) arrayOf("image/*") else arrayOf("*/*")
                        picker.launch(mime)
                    },
                    onView = { viewModel.view(kind) },
                    onDelete = { confirmDelete = kind },
                )
            }
        }

        confirmDelete?.let { kind ->
            AlertDialog(
                onDismissRequest = { confirmDelete = null },
                title = { Text("Delete document?") },
                text = { Text("This file will be removed from your vault. You can upload again later. This can't be undone.") },
                confirmButton = {
                    TextButton(onClick = {
                        confirmDelete = null
                        viewModel.delete(kind)
                    }) { Text("Delete", color = MMInk.Danger) }
                },
                dismissButton = {
                    TextButton(onClick = { confirmDelete = null }) { Text("Cancel", color = MMInk.Text) }
                },
            )
        }

        TextButton(onClick = { showAll = !showAll }, modifier = Modifier.heightIn(min = 48.dp).padding(top = 6.dp)) {
            Text(
                if (showAll) "Collapse records" else "See all records",
                color = MMInk.Text,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun DocumentRow(
    kind: VaultDocumentKind,
    present: Boolean,
    busy: Boolean,
    expanded: Boolean,
    onUpload: () -> Unit,
    onView: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(start = 16.dp, end = 4.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(kind.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MMInk.Text)
            Text(
                if (present) kind.presentSubtitle else kind.missingSubtitle,
                fontSize = 13.sp,
                color = MMInk.Secondary,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        if (present) {
            TextButton(onClick = onView, enabled = !busy) {
                Text("View", color = MMInk.Text, fontWeight = FontWeight.SemiBold)
            }
            TextButton(onClick = onUpload, enabled = !busy) {
                Text(if (busy) "Saving…" else "Replace", color = MMInk.Text, fontWeight = FontWeight.SemiBold)
            }
            IconButton(onClick = onDelete, enabled = !busy) {
                Icon(Icons.Filled.Delete, contentDescription = "Delete ${kind.title}", tint = MMInk.Secondary)
            }
        } else {
            TextButton(onClick = onUpload, enabled = !busy, modifier = Modifier.clip(RoundedCornerShape(20.dp))) {
                Text(
                    when {
                        busy -> "Saving…"
                        expanded -> "Add"
                        else -> "Upload"
                    },
                    color = MMInk.Text,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

private fun displayName(context: android.content.Context, uri: Uri): String {
    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && cursor.moveToFirst()) {
            return cursor.getString(index) ?: "document"
        }
    }
    return "document"
}
