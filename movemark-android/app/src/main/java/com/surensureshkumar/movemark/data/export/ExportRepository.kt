package com.surensureshkumar.movemark.data.export

import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/** Reports through the MoveMark API; the Neon Auth token is attached (and refreshed) by the API client's transport. */
@Singleton
class ExportRepository @Inject constructor(
    private val api: ExportApiClient,
) {
    suspend fun loadExports(propertyId: UUID): List<ExportRow> {
        val items = api.listExports(propertyId)
        return items.map { it.toExportRow() }
    }

    suspend fun queueMoveInReport(propertyId: UUID) {
        api.requestMoveInExport(propertyId)
    }

    suspend fun queueMoveOutReport(propertyId: UUID) {
        api.requestMoveOutExport(propertyId)
    }

    suspend fun queueDisputePacket(propertyId: UUID) {
        api.requestDisputePacketExport(propertyId)
    }

    suspend fun downloadUrl(exportId: UUID): String {
        val resp = api.fetchDownloadUrl(exportId.toString())
        return resp.downloadUrl
    }

    /** True once an in-flight export's PDF can be downloaded (409 until then). */
    suspend fun isReady(exportId: UUID): Boolean = api.isExportReady(exportId.toString())

    fun userMessage(error: Throwable): String = MMUserMessages.export(error)
}
