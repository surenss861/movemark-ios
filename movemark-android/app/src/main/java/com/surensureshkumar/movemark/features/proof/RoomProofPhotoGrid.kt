package com.surensureshkumar.movemark.features.proof

import android.graphics.BitmapFactory
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.IconButton
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMMotion

@Composable
fun RoomProofPhotoGrid(
    photos: List<PendingPhoto>,
    modifier: Modifier = Modifier,
    reduceMotion: Boolean = false,
    /** Removes an unsaved photo; null while a save is running. */
    onRemove: ((String) -> Unit)? = null,
) {
    if (photos.isEmpty()) {
        RoomProofPhotoEmptyState(modifier = modifier)
        return
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        photos.chunked(3).forEach { rowPhotos ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowPhotos.forEach { photo ->
                    val appearedAlpha by animateFloatAsState(
                        targetValue = 1f,
                        animationSpec = MMMotion.receiptEnterSpec(reduceMotion),
                        label = "photo_${photo.id}",
                    )
                    RoomProofPhotoCell(
                        photo = photo,
                        index = photos.indexOf(photo) + 1,
                        onRemove = onRemove,
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .alpha(appearedAlpha),
                    )
                }
                repeat(3 - rowPhotos.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun RoomProofPhotoCell(
    photo: PendingPhoto,
    index: Int,
    onRemove: ((String) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val bitmap = remember(photo.id, photo.bytes) {
        BitmapFactory.decodeByteArray(photo.bytes, 0, photo.bytes.size)
    }
    val borderColor = when (photo.status) {
        PhotoUploadStatus.Failed -> MMColors.SemanticWarning.copy(alpha = 0.85f)
        PhotoUploadStatus.Uploaded -> MMInk.Text.copy(alpha = 0.35f)
        PhotoUploadStatus.Uploading -> MMColors.SemanticWarning.copy(alpha = 0.65f)
        PhotoUploadStatus.Pending -> MMInk.CardStroke
    }
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(MMInk.ThumbFill)
            .border(1.dp, borderColor, RoundedCornerShape(12.dp)),
    ) {
        // A photo that can't be decoded shows the explicit neutral placeholder, never a brand mark.
        if (bitmap == null) {
            Icon(
                imageVector = Icons.Filled.PhotoCamera,
                contentDescription = null,
                tint = MMInk.Secondary,
                modifier = Modifier.align(Alignment.Center).size(22.dp),
            )
        }
        bitmap?.let {
            Image(
                bitmap = it.asImageBitmap(),
                contentDescription = "Photo $index, not uploaded yet",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
        when (photo.status) {
            PhotoUploadStatus.Uploading -> {
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(MMInk.Card.copy(alpha = 0.55f)),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(22.dp),
                        color = MMColors.Primary,
                        strokeWidth = 2.dp,
                    )
                }
            }
            PhotoUploadStatus.Uploaded -> {
                Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = "Uploaded",
                    tint = MMInk.Text,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(5.dp)
                        .size(18.dp)
                        .background(MMInk.Card, CircleShape),
                )
            }
            PhotoUploadStatus.Failed -> {
                Icon(
                    imageVector = Icons.Filled.Warning,
                    contentDescription = "Upload failed",
                    tint = MMColors.SemanticWarning,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(5.dp)
                        .size(18.dp)
                        .background(MMInk.Card, CircleShape),
                )
            }
            PhotoUploadStatus.Pending -> Unit
        }
        if (onRemove != null && (photo.status == PhotoUploadStatus.Pending || photo.status == PhotoUploadStatus.Failed)) {
            IconButton(
                onClick = { onRemove(photo.id) },
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .size(48.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Remove photo $index",
                    tint = MMInk.Text,
                    modifier = Modifier
                        .size(22.dp)
                        .background(MMInk.Card.copy(alpha = 0.92f), CircleShape)
                        .padding(3.dp),
                )
            }
        }
    }
}

@Composable
fun RoomProofPhotoEmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMMetrics.GroupRadius))
            .background(MMInk.Card)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMMetrics.GroupRadius))
            .padding(vertical = 28.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Filled.PhotoCamera,
            contentDescription = null,
            tint = MMInk.Secondary,
            modifier = Modifier.size(28.dp),
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Add photos to create proof for this room.",
            color = MMInk.Secondary,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
        )
    }
}
