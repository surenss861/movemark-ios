package com.surensureshkumar.movemark.features.proof

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCard

@Composable
fun RoomProofMediaModule(
    photos: List<PendingPhoto>,
    isBusy: Boolean,
    reduceMotion: Boolean,
    onTakePhotos: () -> Unit,
    onChooseGallery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier) {
        MMButton(
            text = "Take photos",
            onClick = onTakePhotos,
            enabled = !isBusy,
        )
        Spacer(Modifier.height(10.dp))
        MMButton(
            text = "Choose from gallery",
            onClick = onChooseGallery,
            style = MMButtonStyle.Secondary,
            enabled = !isBusy,
        )

        Spacer(Modifier.height(18.dp))
        Text(
            "Selected photos",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MMColors.TextMuted,
            modifier = Modifier.padding(start = 2.dp, bottom = 10.dp),
        )
        MMProofCard {
            RoomProofPhotoGrid(
                photos = photos,
                reduceMotion = reduceMotion,
            )
        }
    }
}
