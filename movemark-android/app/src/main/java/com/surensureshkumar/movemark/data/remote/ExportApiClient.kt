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

@Serializable
data class ExportListItem(
    val id: String,
    @SerialName("property_id") val propertyId: String,
    val type: String,
    val status: ExportJobStatus,
    @SerialName("requested_at") val requestedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("file_path") val filePath: String? = null,
)

@Serializable
data class MoveInExportResponse(
    @SerialName("export_id") val exportId: String,
    val status: ExportJobStatus,
)

@Serializable
private data class ApiErrorBody(val error: String? = null)

@Singleton
class ExportApiClient @Inject constructor(
    baseUrl: String,
) {
    private val base = baseUrl.trimEnd('/')
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun listExports(accessToken: String, propertyId: UUID): List<ExportListItem> {
        val url = "$base/api/exports?propertyId=$propertyId"
        val body = executeGet(url, accessToken)
        return json.decodeFromString(body)
    }

    suspend fun requestMoveInExport(accessToken: String, propertyId: UUID): MoveInExportResponse {
        val payload = """{"propertyId":"$propertyId","format":"pdf"}"""
        val body = executePost("$base/api/exports/move-in", accessToken, payload)
        return json.decodeFromString(body)
    }

    private fun executeGet(url: String, accessToken: String): String {
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $accessToken")
            .get()
            .build()
        return execute(request)
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

    private fun execute(request: Request): String {
        client.newCall(request).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                val msg = runCatching { json.decodeFromString<ApiErrorBody>(body).error }
                    .getOrNull()
                    ?.takeIf { it.isNotBlank() }
                    ?: resp.message
                throw IllegalStateException(msg)
            }
            return body
        }
    }
}
