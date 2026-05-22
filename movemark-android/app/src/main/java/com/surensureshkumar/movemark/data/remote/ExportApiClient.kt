package com.surensureshkumar.movemark.data.remote

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

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

@Singleton
class ExportApiClient @Inject constructor(
    baseUrl: String,
) {
    private val base = baseUrl.trimEnd('/')
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun listExports(accessToken: String, propertyId: UUID): List<ExportListItem> = try {
        val url = "$base/api/exports?propertyId=$propertyId"
        val body = executeGet(url, accessToken)
        json.decodeFromString(body)
    } catch (e: ExportApiException) {
        throw e
    } catch (_: Exception) {
        throw ExportApiException.Network()
    }

    suspend fun requestMoveInExport(accessToken: String, propertyId: UUID): MoveInExportResponse = try {
        val payload = """{"propertyId":"$propertyId","format":"pdf"}"""
        val body = executePost("$base/api/exports/move-in", accessToken, payload)
        json.decodeFromString(body)
    } catch (e: ExportApiException) {
        throw ExportApiException.QueueFailed()
    } catch (_: Exception) {
        throw ExportApiException.QueueFailed()
    }

    suspend fun fetchDownloadUrl(accessToken: String, exportId: String): ExportDownloadResponse = try {
        val url = "$base/api/exports/$exportId/download"
        val body = executeGet(url, accessToken, allow409 = true)
        json.decodeFromString(body)
    } catch (e: ExportApiException) {
        throw when (e) {
            is ExportApiException.NotReady -> ExportApiException.DownloadFailed("Report is still building. Check back shortly.")
            is ExportApiException.ServerFailed -> ExportApiException.DownloadFailed()
            else -> ExportApiException.DownloadFailed()
        }
    } catch (_: Exception) {
        throw ExportApiException.DownloadFailed()
    }

    private fun executeGet(url: String, accessToken: String, allow409: Boolean = false): String {
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $accessToken")
            .get()
            .build()
        return execute(request, allow409 = allow409)
    }

    private fun executePost(url: String, accessToken: String, jsonBody: String): String {
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $accessToken")
            .header("Content-Type", "application/json")
            .post(jsonBody.toRequestBody("application/json".toMediaType()))
            .build()
        return execute(request)
    }

    private fun execute(request: Request, allow409: Boolean = false): String {
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            when {
                allow409 && resp.code == 409 -> throw ExportApiException.NotReady()
                resp.code == 400 -> {
                    val err = runCatching { json.decodeFromString<ApiErrorBody>(body) }.getOrNull()
                    if (err?.code == "export_failed") {
                        throw ExportApiException.ServerFailed()
                    }
                    throw ExportApiException.Network(sanitizeMessage(body, resp.message))
                }
                !resp.isSuccessful -> throw ExportApiException.Network(sanitizeMessage(body, resp.message))
            }
            return body
        }
    }

    private fun sanitizeMessage(body: String, fallback: String): String {
        val err = runCatching { json.decodeFromString<ApiErrorBody>(body) }.getOrNull()
        val raw = err?.error?.trim().orEmpty()
        if (raw.isBlank() || raw.contains("RevenueCat", ignoreCase = true)) {
            return "Report couldn't load. Try again."
        }
        return raw
    }
}
