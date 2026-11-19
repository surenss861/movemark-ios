package com.surensureshkumar.movemark.data.export

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.Closeable
import java.io.File

/**
 * Renders a downloaded report's pages for the in-app viewer (the Android counterpart of iOS QuickLook), so
 * viewing a report never depends on another PDF app being installed. [PdfRenderer] allows one open page at a
 * time, so renders are serialised.
 */
class PdfPages(file: File) : Closeable {
    private val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    private val renderer = PdfRenderer(descriptor)
    private val lock = Mutex()
    private var closed = false

    val pageCount: Int = renderer.pageCount

    /** Page [index] as a white-backed bitmap [widthPx] wide, keeping the page's aspect ratio. */
    suspend fun render(index: Int, widthPx: Int): Bitmap? = lock.withLock {
        withContext(Dispatchers.IO) {
            if (closed) return@withContext null
            renderer.openPage(index).use { page ->
                val width = widthPx.coerceIn(1, MAX_WIDTH_PX)
                val height = (width.toLong() * page.height / page.width.coerceAtLeast(1)).toInt().coerceAtLeast(1)
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                }
            }
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        runCatching { renderer.close() }
        runCatching { descriptor.close() }
    }

    private companion object {
        /** Keeps one page bitmap well under the per-bitmap memory budget on large tablets. */
        const val MAX_WIDTH_PX = 2000
    }
}
