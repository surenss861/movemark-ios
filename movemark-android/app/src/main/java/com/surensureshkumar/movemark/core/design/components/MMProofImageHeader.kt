package com.surensureshkumar.movemark.core.design.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap

/** @deprecated Use [MMProofPhotoPane] — kept for report thumbnail imports. */
enum class MMProofImageHeaderSize {
    Thumbnail,
    Hero,
}

@Composable
fun MMProofImageHeader(
    modifier: Modifier = Modifier,
    size: MMProofImageHeaderSize = MMProofImageHeaderSize.Thumbnail,
    imageBitmap: ImageBitmap? = null,
    drawableResId: Int? = null,
) {
    val paneSize = when (size) {
        MMProofImageHeaderSize.Thumbnail -> MMProofPhotoPaneSize.Thumbnail
        MMProofImageHeaderSize.Hero -> MMProofPhotoPaneSize.Large
    }
    MMProofPhotoPane(
        modifier = modifier,
        size = paneSize,
        imageBitmap = imageBitmap,
        drawableResId = drawableResId,
    )
}
