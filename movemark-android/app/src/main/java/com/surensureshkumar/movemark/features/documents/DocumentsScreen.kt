package com.surensureshkumar.movemark.features.documents

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Article
import androidx.compose.material.icons.automirrored.outlined.InsertDriveFile
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Draw
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.MonetizationOn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.mmLines
import com.surensureshkumar.movemark.core.design.mmPressable
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import com.surensureshkumar.movemark.features.property.EditRentalSheet
import kotlinx.coroutines.delay

/**
 * The rental's records (iOS `PropertyVaultContent.recordsSection`): "N of 3 added" for lease, deposit receipt and
 * listing proof; those three always listed (Added / Needed, one action each), other records once added or while
 * expanded; Replace and Delete on a long press (and as TalkBack actions). Adding or replacing listing proof opens
 * [ListingProofSheet] first (iOS `startUpload` → `ReplacePhotoSheet`); View opens the file itself, as iOS does.
 *
 * [onEditRental] null presents Edit rental as a sheet over this screen (iOS presents `EditPropertyView` as a sheet).
 */
@Composable
fun DocumentsScreen(
    onBack: () -> Unit,
    onEditRental: (() -> Unit)? = null,
    viewModel: DocumentsViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val documents by viewModel.documents.collectAsState()
    val error by viewModel.error.collectAsState()
    val uploading by viewModel.uploading.collectAsState()
    val deleting by viewModel.deleting.collectAsState()
    val failedUpload by viewModel.failedUpload.collectAsState()
    var confirmDelete by remember { mutableStateOf<VaultDocumentKind?>(null) }
    var showAll by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf(false) }
    var pendingKind by remember { mutableStateOf<VaultDocumentKind?>(null) }
    var showListingProof by remember { mutableStateOf(false) }
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
    fun pick(kind: VaultDocumentKind) {
        pendingKind = kind
        holdBack = true
        val mime = if (kind.acceptsImage) arrayOf("image/*") else arrayOf("*/*")
        picker.launch(mime)
    }
    // iOS `startUpload`: an image record (listing proof) opens the listing-proof sheet first, which picks the
    // screenshot; other records go straight to the file picker. Add, Replace and the TalkBack Replace all land here.
    fun startUpload(kind: VaultDocumentKind) {
        if (kind.acceptsImage) showListingProof = true else pick(kind)
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

    val model = DocumentsModel.from(documents)

    MMScreen(
        title = "Records",
        eyebrow = "Rental record",
        lines = listOf(model.countLine),
        onBack = onBack,
        trailing = {
            TextButton(onClick = { if (onEditRental != null) onEditRental() else editing = true }, modifier = Modifier.heightIn(min = 48.dp)) {
                Text("Edit rental", color = MMInk.HeroText, fontWeight = FontWeight.SemiBold)
            }
        },
    ) {
        DocumentsContent(
            model = model,
            showAll = showAll,
            busyKind = uploading ?: deleting,
            errorMessage = error,
            onRetry = { failedUpload?.let(::pick) ?: viewModel.refresh() },
            onToggle = { showAll = !showAll },
            onView = viewModel::view,
            onAdd = ::startUpload,
            onDelete = { confirmDelete = it },
        )
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

    if (editing) EditRentalSheet(onDismiss = { editing = false })

    if (showListingProof) {
        ListingProofSheet(
            current = ListingProof.current(documents),
            signUrl = viewModel::signedImageUrl,
            onReplace = { pick(VaultDocumentKind.ListingScreenshot) },
            onDismiss = { showListingProof = false },
        )
    }
}

/** Presentational: the error notice, then the records group with its toggle row and long-press footer. */
@Composable
internal fun DocumentsContent(
    model: DocumentsModel,
    showAll: Boolean,
    busyKind: VaultDocumentKind?,
    errorMessage: String?,
    onRetry: () -> Unit,
    onToggle: () -> Unit,
    onView: (VaultDocumentKind) -> Unit,
    onAdd: (VaultDocumentKind) -> Unit,
    onDelete: (VaultDocumentKind) -> Unit,
) {
    val large = mmIsLargeFont()
    val dividerLeading = if (large) 16.dp else 52.dp
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        errorMessage?.let { MMNotice(message = it, actionTitle = "Try again", onAction = onRetry) }
        MMGroup(footer = model.footer) {
            model.visibleRecords(showAll).forEachIndexed { index, record ->
                if (index > 0) MMRowDivider(leading = dividerLeading)
                RecordRow(
                    record = record,
                    busy = busyKind == record.kind,
                    onView = { onView(record.kind) },
                    onAdd = { onAdd(record.kind) },
                    onDelete = { onDelete(record.kind) },
                )
            }
            if (model.showsToggle) {
                MMRowDivider(leading = dividerLeading)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .mmPressable(onClick = onToggle)
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        if (showAll) Icons.Filled.KeyboardArrowUp else Icons.Filled.Add,
                        contentDescription = null,
                        tint = MMInk.Secondary,
                        modifier = Modifier.size(18.dp).width(24.dp),
                    )
                    Text(
                        if (showAll) DocumentsModel.TOGGLE_FEWER else DocumentsModel.TOGGLE_MORE,
                        style = mmFont(15.5f),
                        color = MMInk.Text,
                        modifier = Modifier.weight(1f),
                    )
                    if (!showAll && !large) {
                        Text(DocumentsModel.TOGGLE_DETAIL, style = mmFont(13f), color = MMInk.Secondary, maxLines = 1)
                    }
                }
            }
        }
    }
}

/**
 * One record (iOS `MMRecordRow`): type icon, title, "Added Oct 19, 2025" or "Needed · reason", the file on its own
 * quiet line, and one action pill — View when on file, Add when not. Replace and Delete sit behind a long press.
 */
@Composable
private fun RecordRow(
    record: DocumentsModel.Record,
    busy: Boolean,
    onView: () -> Unit,
    onAdd: () -> Unit,
    onDelete: () -> Unit,
) {
    val large = mmIsLargeFont()
    val haptics = LocalHapticFeedback.current
    var menuOpen by remember { mutableStateOf(false) }
    val title = record.kind.title
    val replaceTitle = if (record.kind.acceptsImage) "Replace with photo" else "Replace"
    val canManage = record.isPresent && !busy
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .then(
                    if (canManage) {
                        Modifier
                            .pointerInput(record.kind) {
                                detectTapGestures(onLongPress = {
                                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                    menuOpen = true
                                })
                            }
                            .semantics {
                                customActions = listOf(
                                    CustomAccessibilityAction(replaceTitle) { onAdd(); true },
                                    CustomAccessibilityAction("Delete") { onDelete(); true },
                                )
                            }
                    } else {
                        Modifier
                    },
                )
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (!large) {
                Icon(
                    recordIcon(record.kind),
                    contentDescription = null,
                    tint = MMInk.Text.copy(alpha = if (record.isPresent) 0.8f else 0.45f),
                    modifier = Modifier.size(20.dp).width(24.dp),
                )
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = mmFont(16f), color = MMInk.Text, maxLines = mmLines(2), overflow = TextOverflow.Ellipsis)
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(color = if (record.isPresent) MMInk.Text else MMInk.Warning)) { append(record.statusLead) }
                        record.statusDetail?.let { withStyle(SpanStyle(color = MMInk.Secondary)) { append(it) } }
                    },
                    style = mmFont(13f),
                    maxLines = mmLines(2),
                    overflow = TextOverflow.Ellipsis,
                )
                val file = record.file
                if (record.isPresent && !file.isNullOrEmpty()) {
                    Text(
                        file,
                        style = mmFont(12.5f),
                        color = MMInk.Secondary,
                        maxLines = mmLines(1),
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            if (record.isPresent && !busy) {
                RecordActionPill(title = "View", label = "View $title", onClick = onView)
            } else {
                RecordActionPill(title = "Add", label = "Add $title", busy = busy, onClick = onAdd)
            }
        }
        DropdownMenu(expanded = menuOpen && canManage, onDismissRequest = { menuOpen = false }) {
            DropdownMenuItem(text = { Text(replaceTitle) }, onClick = { menuOpen = false; onAdd() })
            DropdownMenuItem(text = { Text("Delete", color = MMInk.Danger) }, onClick = { menuOpen = false; onDelete() })
        }
    }
}

/** The one-word row action (iOS `MMRowActionLabel`): quiet filled capsule, ink text; "Saving…" while busy. */
@Composable
private fun RecordActionPill(title: String, label: String, busy: Boolean = false, onClick: () -> Unit) {
    // A 48dp touch target around the 30dp capsule.
    Box(
        Modifier
            .heightIn(min = 48.dp)
            .mmPressable(enabled = !busy, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier
                .clip(CircleShape)
                .background(MMInk.Field)
                .heightIn(min = 30.dp)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (busy) CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 1.5.dp, modifier = Modifier.size(12.dp))
            Text(if (busy) "Saving…" else title, style = mmFont(14f, FontWeight.SemiBold), color = MMInk.Text)
        }
    }
}

/** iOS `PropertyVaultContent.recordIcon`, in Material's outlined set. */
internal fun recordIcon(kind: VaultDocumentKind): ImageVector = when (kind) {
    VaultDocumentKind.Lease -> Icons.Outlined.Draw
    VaultDocumentKind.DepositReceipt -> Icons.Outlined.MonetizationOn
    VaultDocumentKind.ListingScreenshot -> Icons.Outlined.Image
    VaultDocumentKind.CleaningReceipt -> Icons.Outlined.AutoAwesome
    VaultDocumentKind.UtilityProof -> Icons.Outlined.Bolt
    VaultDocumentKind.MoveOutInvoice -> Icons.AutoMirrored.Outlined.Article
    VaultDocumentKind.Other -> Icons.AutoMirrored.Outlined.InsertDriveFile
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
