package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMColors
import android.graphics.BitmapFactory

@Composable
fun RoomProofPhotoStrip(
    photos: List<PendingPhoto>,
    modifier: Modifier = Modifier,
) {
    if (photos.isEmpty()) return
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(photos, key = { it.id }) { photo ->
            val bitmap = remember(photo.id, photo.status) {
                BitmapFactory.decodeByteArray(photo.bytes, 0, photo.bytes.size)
            }
            val borderColor = when (photo.status) {
                PhotoUploadStatus.Failed -> MMColors.SemanticDanger
                PhotoUploadStatus.Uploaded -> MMColors.Primary.copy(alpha = 0.6f)
                PhotoUploadStatus.Uploading -> MMColors.SemanticWarning
                PhotoUploadStatus.Pending -> MMColors.CardStroke
            }
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .border(2.dp, borderColor, RoundedCornerShape(10.dp)),
            ) {
                bitmap?.let {
                    Image(
                        bitmap = it.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                    )
                }
                if (photo.status == PhotoUploadStatus.Failed) {
                    Icon(
                        imageVector = Icons.Filled.Warning,
                        contentDescription = "Upload failed",
                        tint = MMColors.SemanticDanger,
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(4.dp)
                            .size(18.dp),
                    )
                }
            }
        }
    }
}
