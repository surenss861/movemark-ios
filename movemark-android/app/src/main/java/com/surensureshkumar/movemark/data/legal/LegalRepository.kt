/**
 * @file The app's side of the legal gate. The server owns versions, time and enforcement; nothing here is remembered
 *       as "accepted" on the device.
 * @domain onboarding-auth
 * @status wip
 * @see [[LegalGate.swift]] — iOS counterpart
 */
package com.surensureshkumar.movemark.data.legal

import com.surensureshkumar.movemark.data.backend.PostgrestClient
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

@Serializable
data class LegalDocument(val version: String, val url: String? = null)

@Serializable
data class LegalDocuments(
    val terms: LegalDocument,
    @SerialName("privacy_notice") val privacyNotice: LegalDocument,
)

/** `rpc get_legal_status()`. */
@Serializable
data class LegalStatus(
    val enforced: Boolean = false,
    @SerialName("acceptance_required") val acceptanceRequired: Boolean = false,
    val blocked: Boolean = false,
    val documents: LegalDocuments? = null,
) {
    /** Show the gate only when there is something real to accept. */
    val needsAcceptance: Boolean get() = acceptanceRequired && documents != null
}

@Singleton
class LegalRepository @Inject constructor(private val postgrest: PostgrestClient) {
    /** Null when the server has no gate or can't be reached: this only offers the step, the server enforces it. */
    suspend fun status(): LegalStatus? =
        runCatching { postgrest.rpc("get_legal_status", LegalStatus.serializer()) }.getOrNull()

    suspend fun accept(method: String, documents: LegalDocuments): LegalStatus =
        postgrest.rpc(
            "accept_legal_documents",
            LegalStatus.serializer(),
            buildJsonObject {
                put("p_method", method)
                put("p_terms_version", documents.terms.version)
                put("p_privacy_notice_version", documents.privacyNotice.version)
            },
        )
}
