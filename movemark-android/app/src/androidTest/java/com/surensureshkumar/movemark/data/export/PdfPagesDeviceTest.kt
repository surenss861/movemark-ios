package com.surensureshkumar.movemark.data.export

import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class PdfPagesDeviceTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    /** A two-page US Letter PDF in the reports folder, as ReportFileDownloader leaves it. */
    private fun reportPdf(): File {
        val doc = PdfDocument()
        repeat(2) { i ->
            val page = doc.startPage(PdfDocument.PageInfo.Builder(612, 792, i + 1).create())
            page.canvas.drawText("MoveMark page ${i + 1}", 72f, 72f, Paint().apply { color = Color.BLACK })
            doc.finishPage(page)
        }
        val file = File(File(context.cacheDir, "movemark_reports").apply { mkdirs() }, "MoveMark_Move-In_Report_test.pdf")
        file.outputStream().use { doc.writeTo(it) }
        doc.close()
        return file
    }

    @Test
    fun rendersEveryPageAtTheRequestedWidthKeepingAspect(): Unit = runBlocking {
        val file = reportPdf()
        PdfPages(file).use { pages ->
            assertEquals(2, pages.pageCount)
            val bitmap = pages.render(1, 1000)
            assertNotNull(bitmap)
            assertEquals(1000, bitmap!!.width)
            assertEquals(1294, bitmap.height) // 1000 * 792 / 612
            // White-backed page with dark text somewhere on it.
            assertEquals(Color.WHITE, bitmap.getPixel(999, 1293))
        }
        file.delete()
    }

    @Test
    fun renderAfterCloseIsSafe(): Unit = runBlocking {
        val file = reportPdf()
        val pages = PdfPages(file)
        pages.close()
        assertNull(pages.render(0, 500))
        file.delete()
    }

    @Test
    fun reportsAreSharedThroughTheFileProvider() {
        val file = reportPdf()
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        assertEquals("content", uri.scheme)
        assertTrue(uri.toString().contains("movemark_reports"))
        context.contentResolver.openInputStream(uri)!!.use { assertTrue(it.read() >= 0) }
        file.delete()
    }
}
