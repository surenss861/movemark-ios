package com.surensureshkumar.movemark.features.reports.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.data.export.PdfPages
import java.io.File

/** A downloaded report, read in the app (iOS shows it in QuickLook). Share hands the same file to the system sheet. */
@Composable
fun ReportPdfViewer(
    file: File,
    title: String,
    onShare: () -> Unit,
    onClose: () -> Unit,
) {
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        val pages = remember(file) { runCatching { PdfPages(file) }.getOrNull() }
        DisposableEffect(pages) { onDispose { pages?.close() } }

        Column(
            Modifier
                .fillMaxSize()
                .background(MMColors.EvidenceCard),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 4.dp, vertical = 4.dp),
            ) {
                IconButton(onClick = onClose) {
                    Icon(Icons.Filled.Close, contentDescription = "Close report", tint = MMColors.TextPrimary)
                }
                Text(
                    title,
                    color = MMColors.TextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .weight(1f)
                        .semantics { heading() },
                )
                IconButton(onClick = onShare) {
                    Icon(Icons.Filled.Share, contentDescription = "Share report", tint = MMColors.Primary)
                }
            }
            if (pages == null || pages.pageCount == 0) {
                Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text(
                        "This report couldn’t be opened here. Use Share to open it in another app.",
                        color = MMColors.TextSecondary,
                        fontSize = 15.sp,
                    )
                }
            } else {
                BoxWithConstraints(Modifier.fillMaxSize()) {
                    val widthPx = with(LocalDensity.current) { (maxWidth - 24.dp).roundToPx() }
                    LazyColumn(
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        items(pages.pageCount) { index ->
                            PdfPage(pages, index, widthPx)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PdfPage(pages: PdfPages, index: Int, widthPx: Int) {
    val bitmap = remember(index, widthPx) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(index, widthPx) {
        bitmap.value = runCatching { pages.render(index, widthPx) }.getOrNull()?.asImageBitmap()
    }
    val label = "Page ${index + 1} of ${pages.pageCount}"
    val image by bitmap
    val current = image
    if (current == null) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(PAGE_ASPECT)
                .background(Color.White)
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(color = MMColors.Primary)
        }
    } else {
        Image(
            bitmap = current,
            contentDescription = label,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(current.width.toFloat() / current.height),
        )
    }
}

/** US Letter, the reports' page size, until the real page is rendered. */
private const val PAGE_ASPECT = 8.5f / 11f
