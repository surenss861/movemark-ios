package com.surensureshkumar.movemark.features.documents

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
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMCaseFilePlate
import com.surensureshkumar.movemark.domain.VaultDocumentKind

@Composable
fun DocumentsScreen(
    onBack: () -> Unit,
    viewModel: DocumentsViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val documents by viewModel.documents.collectAsState()
    val error by viewModel.error.collectAsState()
    val uploading by viewModel.uploading.collectAsState()
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

    MMBackground {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(bottom = 32.dp),
        ) {
            TextButton(onClick = onBack) {
                Text("Back", color = MMColors.TextSecondary)
            }
            Text(
                "RECEIPTS & LEASE DOCS",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.8.sp,
                color = MMColors.TextSecondary,
            )
            Text(
                "Lease, deposit receipt, and other papers.",
                fontSize = 15.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                "$uploaded of ${VaultDocumentKind.all.size} uploaded",
                fontSize = 12.sp,
                color = MMColors.TextMuted,
                modifier = Modifier.padding(top = 8.dp, bottom = 16.dp),
            )

            error?.let {
                Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
                Spacer(Modifier.height(12.dp))
            }

            // Collapsed, this lists only missing priority records (as on iOS); with all three on
            // file there is nothing to list, so no empty plate — just "See all records".
            if (visible.isNotEmpty()) MMCaseFilePlate {
                visible.forEachIndexed { index, kind ->
                    val present = VaultDocumentKind.isPresent(kind, types)
                    if (index > 0) Spacer(Modifier.height(14.dp))
                    DocumentRow(
                        kind = kind,
                        present = present,
                        busy = uploading == kind,
                        expanded = showAll,
                        onUpload = {
                            pendingKind = kind
                            holdBack = true
                            val mime = if (kind.acceptsImage) arrayOf("image/*") else arrayOf("*/*")
                            picker.launch(mime)
                        },
                        onView = { viewModel.view(kind) },
                    )
                }
            }

            TextButton(onClick = { showAll = !showAll }) {
                Text(
                    if (showAll) "Collapse records" else "See all records",
                    color = MMColors.Primary,
                    fontWeight = FontWeight.SemiBold,
                )
            }
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
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(kind.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary)
            Text(
                if (present) kind.presentSubtitle else kind.missingSubtitle,
                fontSize = 13.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        if (present) {
            TextButton(onClick = onView, enabled = !busy) {
                Text("View", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
            }
            TextButton(onClick = onUpload, enabled = !busy) {
                Text(if (busy) "Saving…" else "Replace", color = MMColors.TextPrimary, fontWeight = FontWeight.SemiBold)
            }
        } else {
            TextButton(onClick = onUpload, enabled = !busy, modifier = Modifier.clip(RoundedCornerShape(20.dp))) {
                Text(
                    when {
                        busy -> "Saving…"
                        expanded -> "Add"
                        else -> "Upload"
                    },
                    color = MMColors.TextPrimary,
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
