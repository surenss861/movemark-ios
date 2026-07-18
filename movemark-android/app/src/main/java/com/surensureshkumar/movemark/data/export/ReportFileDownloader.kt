package com.surensureshkumar.movemark.data.export

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

object ReportFileDownloader {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private fun baseNameFor(exportType: String): String = when (exportType) {
        ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> "MoveMark_Move-In_Report"
        ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> "MoveMark_Move-Out_Report"
        ReportReadinessMapper.DISPUTE_PACKET_TYPE -> "MoveMark_Dispute_Packet"
        else -> "MoveMark_Report"
    }

    /** Scoped by exportId so downloading reports for two different properties/exports back-to-back can't overwrite each other. */
    fun fileNameFor(exportType: String, exportId: String): String {
        val suffix = exportId.take(8)
        return "${baseNameFor(exportType)}_$suffix.pdf"
    }

    fun displayTitle(exportType: String): String = when (exportType) {
        ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> "Move-in report"
        ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> "Move-out report"
        ReportReadinessMapper.DISPUTE_PACKET_TYPE -> "Dispute packet"
        else -> "Report"
    }

    suspend fun download(context: Context, signedUrl: String, exportType: String, exportId: String): File =
        withContext(Dispatchers.IO) {
            val request = Request.Builder().url(signedUrl).get().build()
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IOException("Couldn't download report.")
                }
                val bytes = response.body?.bytes()
                    ?: throw IOException("Report file was empty.")
                val directory = File(context.cacheDir, "movemark_reports").apply { mkdirs() }
                val file = File(directory, fileNameFor(exportType, exportId))
                file.writeBytes(bytes)
                file
            }
        }
}
