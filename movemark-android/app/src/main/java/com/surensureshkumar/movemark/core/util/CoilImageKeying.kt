package com.surensureshkumar.movemark.core.util

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import coil.request.ImageRequest

/**
 * Builds a Coil [ImageRequest] for a Supabase Storage signed URL, cache-keyed by the stable
 * storage [path] rather than the full signed URL.
 *
 * Signed URLs mint a fresh token/expiry on every re-fetch, so Coil's default behavior of caching
 * by the full request URL is a guaranteed cache miss on every re-mint of the same underlying photo.
 * Keying memory/disk cache entries by the storage path instead means repeated views of the same
 * photo hit the cache even after its signed URL token changes.
 *
 * Returns null when there's no URL yet (caller should fall back to a placeholder), and falls back
 * to Coil's default URL-based key when [path] isn't available.
 */
@Composable
fun rememberSignedImageRequest(url: String?, path: String? = null): ImageRequest? {
    val context = LocalContext.current
    return remember(url, path) {
        val trimmedUrl = url?.trim()
        if (trimmedUrl.isNullOrEmpty()) {
            null
        } else {
            ImageRequest.Builder(context)
                .data(trimmedUrl)
                .apply {
                    val trimmedPath = path?.trim()
                    if (!trimmedPath.isNullOrEmpty()) {
                        memoryCacheKey(trimmedPath)
                        diskCacheKey(trimmedPath)
                    }
                }
                .build()
        }
    }
}
