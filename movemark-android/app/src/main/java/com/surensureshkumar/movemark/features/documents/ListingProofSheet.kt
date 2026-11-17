package com.surensureshkumar.movemark.features.documents

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.data.models.PropertyDocumentRow
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.util.Locale

/**
 * Listing proof as archived source material (iOS `ReplacePhotoSheet`, ListingProofSheet.swift): the original listing
 * image on file with the date it was added and "Source preserved", or a quiet empty frame explaining why it's worth
 * keeping; then the one action that picks a screenshot. The upload itself stays with the records screen.
 */
object ListingProof {
    /** The listing image on file (iOS `ReplacePhotoSheet.Current`). */
    data class Current(
        /** The stored image to show: the thumbnail when there is one, else the file (iOS `listingPreview`). */
        val path: String,
        /** "Oct 12, 2025", when the stored timestamp reads. */
        val addedOn: String?,
    ) {
        /** "Added Oct 12, 2025"; null hides the line, as iOS does without a date. */
        val addedLine: String? get() = addedOn?.takeIf { it.isNotBlank() }?.let { "Added $it" }
    }

    const val TITLE = "Listing proof"
    const val INTRO_CURRENT = "How the rental was advertised, kept with your record as source material."
    const val INTRO_EMPTY =
        "A screenshot of the original ad shows what was promised — appliances, finishes and condition — in the landlord's own words."
    const val ORIGINAL = "Original listing"
    const val SOURCE_PRESERVED = "Source preserved"
    const val EMPTY_FRAME = "No listing saved yet"
    const val IMAGE_LABEL = "Original listing image"
    const val ACTION_REPLACE = "Replace screenshot"
    const val ACTION_CHOOSE = "Choose screenshot"
    const val CAPTION_CURRENT = "The current image stays on file until the new one is saved."
    const val CAPTION_EMPTY = "Saved as you chose it, with the date it was added."
    const val CANCEL = "Cancel"

    fun intro(current: Current?): String = if (current == null) INTRO_EMPTY else INTRO_CURRENT
    fun action(current: Current?): String = if (current == null) ACTION_CHOOSE else ACTION_REPLACE
    fun caption(current: Current?): String = if (current == null) CAPTION_EMPTY else CAPTION_CURRENT

    /** The listing-proof row on file, as the sheet shows it; null when there is none (iOS `listingPreview`). */
    fun current(
        rows: List<PropertyDocumentRow>,
        locale: Locale = Locale.getDefault(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Current? {
        val keys = VaultDocumentKind.ListingScreenshot.queryKeys()
        val row = rows.firstOrNull { it.documentType in keys } ?: return null
        val path = row.thumbnailPath?.trim()?.takeIf { it.isNotEmpty() } ?: row.filePath
        return Current(path = path, addedOn = row.uploadedAt?.let { DocumentsModel.recordDate(it, locale, zone) })
    }
}

/**
 * The sheet over the records screen (iOS presents `ReplacePhotoSheet` with `.sheet`, Cancel in the toolbar).
 * [signUrl] mints a signed URL for the stored image (null when it can't be signed); [onReplace] runs after the sheet
 * hides, and opens the image picker the screen already owns.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ListingProofSheet(
    current: ListingProof.Current?,
    signUrl: suspend (String) -> String?,
    onReplace: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    fun hide(then: () -> Unit) {
        scope.launch { sheetState.hide() }.invokeOnCompletion { then() }
    }

    // iOS `MMEvidenceImage`: resolve once per path; an unsigned path shows the failure frame.
    var imageUrl by remember(current?.path) { mutableStateOf<String?>(null) }
    var imageFailed by remember(current?.path) { mutableStateOf(false) }
    LaunchedEffect(current?.path) {
        val path = current?.path ?: return@LaunchedEffect
        val url = runCatching { signUrl(path) }.getOrNull()
        if (url.isNullOrBlank()) imageFailed = true else imageUrl = url
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MMInk.Sheet,
        contentColor = MMInk.Text,
        dragHandle = { BottomSheetDefaults.DragHandle(color = MMInk.Separator) },
    ) {
        ListingProofSheetContent(
            current = current,
            imageUrl = imageUrl,
            imageFailed = imageFailed,
            onReplace = { hide { onDismiss(); onReplace() } },
            onCancel = { hide(onDismiss) },
        )
    }
}

/** Presentational: Cancel and the title, the line, the archived card (or empty frame), the action and its caption. */
@Composable
internal fun ListingProofSheetContent(
    current: ListingProof.Current?,
    imageUrl: String?,
    imageFailed: Boolean,
    onReplace: () -> Unit,
    onCancel: () -> Unit,
) {
    val large = mmIsLargeFont()
    Column(Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 8.dp)) {
            TextButton(onClick = onCancel, modifier = Modifier.align(Alignment.CenterStart)) {
                Text(ListingProof.CANCEL, style = mmFont(16f), color = MMInk.Text)
            }
            Text(
                ListingProof.TITLE,
                style = mmFont(17f, FontWeight.SemiBold),
                color = MMInk.Text,
                modifier = Modifier.align(Alignment.Center).semantics { heading() },
            )
        }
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMMetrics.Inset)
                .padding(top = 12.dp, bottom = 32.dp),
        ) {
            Text(ListingProof.intro(current), style = mmFont(15f), color = MMInk.Secondary)
            Spacer(Modifier.height(20.dp))
            if (current != null) {
                ArchivedListingCard(current, imageUrl, imageFailed, imageHeight = if (large) 220 else 320)
            } else {
                MissingListingFrame(height = if (large) 120 else 180)
            }
            Spacer(Modifier.height(22.dp))
            MMPrimaryButton(
                title = ListingProof.action(current),
                onClick = onReplace,
                icon = Icons.Outlined.PhotoLibrary,
            )
            Spacer(Modifier.height(10.dp))
            Text(
                ListingProof.caption(current),
                style = mmFont(12.5f),
                color = MMInk.Secondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/** iOS `ReplacePhotoSheet.archived`: the whole image (fit) on paper, then the label block, in a stroked card. */
@Composable
private fun ArchivedListingCard(current: ListingProof.Current, imageUrl: String?, imageFailed: Boolean, imageHeight: Int) {
    val cardShape = RoundedCornerShape(MMMetrics.CardRadius)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, cardShape)
            .padding(12.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(imageHeight.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MMInk.Paper)
                .semantics { contentDescription = ListingProof.IMAGE_LABEL },
        ) {
            when {
                imageUrl != null -> SubcomposeAsyncImage(
                    model = imageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize(),
                    loading = { Box(Modifier.fillMaxSize().background(MMInk.Field)) },
                    error = { ImageFailure() },
                )
                imageFailed -> ImageFailure()
                else -> Box(Modifier.fillMaxSize().background(MMInk.Field))
            }
        }
        Column(
            Modifier
                .fillMaxWidth()
                .padding(top = 12.dp)
                .semantics(mergeDescendants = true) {},
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(ListingProof.ORIGINAL, style = mmFont(15f, FontWeight.SemiBold), color = MMInk.Text)
            current.addedLine?.let {
                Text(it, style = mmFont(13f).copy(fontFeatureSettings = "tnum"), color = MMInk.Secondary)
            }
            Row(
                Modifier.padding(top = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Outlined.Verified, contentDescription = null, tint = MMInk.Text, modifier = Modifier.size(14.dp))
                Text(ListingProof.SOURCE_PRESERVED, style = mmFont(13f, FontWeight.Medium), color = MMInk.Text)
            }
        }
    }
}

/** iOS `MMEvidenceImage.failureView`: the placeholder with a light photo glyph, never a broken image. */
@Composable
private fun ImageFailure() {
    Box(Modifier.fillMaxSize().background(MMInk.Field), contentAlignment = Alignment.Center) {
        Icon(Icons.Outlined.Image, contentDescription = null, tint = MMInk.Secondary.copy(alpha = 0.6f), modifier = Modifier.size(22.dp))
    }
}

/** iOS `MMMissingPhotoFrame("No listing saved yet")`: a quiet dashed frame on the field colour. */
@Composable
private fun MissingListingFrame(height: Int) {
    val stroke = MMInk.Secondary.copy(alpha = 0.45f)
    Box(
        Modifier
            .fillMaxWidth()
            .height(height.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MMInk.Field)
            .drawBehind {
                val inset = 0.5.dp.toPx()
                drawRoundRect(
                    color = stroke,
                    topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                    size = androidx.compose.ui.geometry.Size(size.width - inset * 2, size.height - inset * 2),
                    cornerRadius = CornerRadius(12.dp.toPx()),
                    style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))),
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(ListingProof.EMPTY_FRAME, style = mmFont(12.5f), color = MMInk.Secondary)
    }
}
