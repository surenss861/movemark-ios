package com.surensureshkumar.movemark.data.export

import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.remote.ExportApiException
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ExportRepository @Inject constructor(
    private val api: ExportApiClient,
    private val sessionManager: SessionManager,
) {
    private suspend fun token(): String =
        sessionManager.accessToken() ?: throw ExportApiException.Network("Sign in required.")

    suspend fun loadExports(propertyId: UUID): List<ExportRow> {
        val items = api.listExports(token(), propertyId)
        return items.map { it.toExportRow() }
    }

    suspend fun queueMoveInReport(propertyId: UUID) {
        api.requestMoveInExport(token(), propertyId)
    }

    suspend fun queueMoveOutReport(propertyId: UUID) {
        api.requestMoveOutExport(token(), propertyId)
    }

    suspend fun queueDisputePacket(propertyId: UUID) {
        api.requestDisputePacketExport(token(), propertyId)
    }

    suspend fun downloadUrl(exportId: UUID): String {
        val resp = api.fetchDownloadUrl(token(), exportId.toString())
        return resp.downloadUrl
    }

    fun userMessage(error: Throwable): String = MMUserMessages.export(error)
}
