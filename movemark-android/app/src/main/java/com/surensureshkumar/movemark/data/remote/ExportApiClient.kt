package com.surensureshkumar.movemark.data.remote

import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.resolvePath
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.UUID

@Serializable
enum class ExportJobStatus {
    @SerialName("queued") Queued,
    @SerialName("processing") Processing,
    @SerialName("completed") Completed,
    @SerialName("failed") Failed,
}

/** Matches movemark-api list JSON (camelCase). */
@Serializable
data class ExportListItem(
    val id: String,
    val userId: String? = null,
    val propertyId: String,
    val type: String,
    val status: ExportJobStatus,
    val requestedAt: String? = null,
    val completedAt: String? = null,
    val filePath: String? = null,
    val createdAt: String? = null,
)

@Serializable
data class MoveInExportResponse(
    val exportId: String,
    val status: ExportJobStatus,
)

@Serializable
data class ExportDownloadResponse(
    val exportId: String,
    val status: ExportJobStatus,
    val downloadUrl: String,
    val expiresInSeconds: Int = 3600,
)

sealed class ExportApiException(message: String) : Exception(message) {
    class NotReady : ExportApiException("Report is still processing.")
    class ServerFailed : ExportApiException("This report failed on the server. Try making a new one.")
    class Network(message: String = "Report couldn't load. Try again.") : ExportApiException(message)
    class QueueFailed(message: String = "Report couldn't be started. Try again.") : ExportApiException(message)
    class DownloadFailed(message: String = "Report couldn't be opened. Try again.") : ExportApiException(message)
}

@Serializable
private data class ApiErrorBody(val error: String? = null, val code: String? = null)

/** The MoveMark API's report endpoints (and account deletion), signed in through [AuthenticatedTransport]. */
class ExportApiClient(
    private val baseUrl: HttpUrl?,
    private val transport: AuthenticatedTransport,
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun listExports(propertyId: UUID): List<ExportListItem> = try {
        val body = executeGet(url("api/exports").newBuilder().addQueryParameter("propertyId", propertyId.toString()).build())
        json.decodeFromString(body)
    } catch (e: ExportApiException) {
        throw e
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        throw ExportApiException.Network()
    }

    suspend fun requestMoveInExport(propertyId: UUID): MoveInExportResponse =
        requestExport("api/exports/move-in", propertyId)

    suspend fun requestMoveOutExport(propertyId: UUID): MoveInExportResponse =
        requestExport("api/exports/move-out", propertyId)

    suspend fun requestDisputePacketExport(propertyId: UUID): MoveInExportResponse =
        requestExport("api/exports/dispute-packet", propertyId)

    private suspend fun requestExport(path: String, propertyId: UUID): MoveInExportResponse =
        try {
            val payload = """{"propertyId":"$propertyId","format":"pdf"}"""
            val body = executePost(url(path), payload)
            json.decodeFromString(body)
        } catch (e: ExportApiException) {
            throw e
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            throw ExportApiException.QueueFailed()
        }

    suspend fun fetchDownloadUrl(exportId: String): ExportDownloadResponse = try {
        val body = executeGet(url("api/exports/$exportId/download"), allow409 = true)
        json.decodeFromString(body)
    } catch (e: ExportApiException) {
        throw when (e) {
            is ExportApiException.NotReady -> ExportApiException.DownloadFailed("Report is still building. Check back shortly.")
            is ExportApiException.ServerFailed -> ExportApiException.DownloadFailed()
            else -> ExportApiException.DownloadFailed()
        }
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        throw ExportApiException.DownloadFailed()
    }

    /**
     * Whether a queued/processing export's file is ready: the download endpoint answers 409 until the worker
     * has written it, 200 once it can be signed. Used to poll an in-flight export; the URL itself is discarded.
     */
    suspend fun isExportReady(exportId: String): Boolean = try {
        executeGet(url("api/exports/$exportId/download"), allow409 = true)
        true
    } catch (_: ExportApiException.NotReady) {
        false
    }

    /** Permanently deletes the signed-in account and its cloud data (`DELETE /api/account`, 204). */
    suspend fun deleteAccount() {
        val response = try {
            transport.execute(Request.Builder().url(url("api/account")).delete().build())
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            throw ExportApiException.Network("Couldn’t delete your account. Check your connection and try again.")
        }
        if (!response.isSuccessful) {
            val err = runCatching { json.decodeFromString<ApiErrorBody>(response.bodyString()) }.getOrNull()
            val message = err?.error?.trim().orEmpty()
            throw ExportApiException.Network(
                if (message.isBlank() || MMUserMessages.isTechnical(message)) "Couldn’t delete your account. Try again." else message,
            )
        }
    }

    private fun url(path: String): HttpUrl =
        (baseUrl ?: throw ExportApiException.Network("This build is not configured to reach MoveMark’s servers."))
            .resolvePath(path)

    private suspend fun executeGet(url: HttpUrl, allow409: Boolean = false): String =
        execute(Request.Builder().url(url).get().build(), allow409 = allow409)

    private suspend fun executePost(url: HttpUrl, jsonBody: String): String =
        execute(Request.Builder().url(url).post(jsonBody.toRequestBody("application/json".toMediaType())).build())

    private suspend fun execute(request: Request, allow409: Boolean = false): String {
        val resp = transport.execute(request)
        val body = resp.bodyString()
        val err = runCatching { json.decodeFromString<ApiErrorBody>(body) }.getOrNull()
        when {
            allow409 && resp.code == 409 -> throw ExportApiException.NotReady()
            resp.code == 409 && err?.code == "export_already_processing" ->
                throw ExportApiException.QueueFailed("A move-out report is already building. Check back shortly.")
            resp.code == 400 -> {
                when (err?.code) {
                    "export_failed" -> throw ExportApiException.ServerFailed()
                    "not_enough_move_out_proof" ->
                        throw ExportApiException.QueueFailed(
                            "Capture move-out proof for at least one room first.",
                        )
                    "not_enough_dispute_proof" ->
                        throw ExportApiException.QueueFailed(
                            "Add move-in room proof before building a dispute packet.",
                        )
                }
                throw ExportApiException.Network(sanitizeMessage(body))
            }
            resp.code == 429 -> throw ExportApiException.Network("That’s a lot at once. Wait a minute, then try again.")
            !resp.isSuccessful -> throw ExportApiException.Network(sanitizeMessage(body))
        }
        return body
    }

    private fun sanitizeMessage(body: String): String {
        val err = runCatching { json.decodeFromString<ApiErrorBody>(body) }.getOrNull()
        val raw = err?.error?.trim().orEmpty()
        if (raw.isBlank() || MMUserMessages.isTechnical(raw)) {
            return "Report couldn't be started. Try again."
        }
        return raw
    }
}
