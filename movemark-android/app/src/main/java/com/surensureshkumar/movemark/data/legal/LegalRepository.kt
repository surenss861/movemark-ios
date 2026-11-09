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
import kotlinx.serialization.json.JsonObject
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
    /**
     * The age statement the renter must confirm (migration 1055). Null from a server without 1055, which neither
     * records nor requires it: the gate then sends the three-argument call, exactly as before.
     */
    @SerialName("age_requirement") val ageRequirement: String? = null,
    /** The account's declared age category ('teen' or 'adult'), once declared through the age-range question. */
    @SerialName("age_category") val ageCategory: String? = null,
) {
    /** Show the gate only when there is something real to accept. */
    val needsAcceptance: Boolean get() = acceptanceRequired && documents != null

    /** True when the server requires an age statement this build doesn't know: the renter must update the app. */
    val requiresAppUpdate: Boolean get() = ageRequirement != null && ageRequirement != LegalAgeChoice.BANDS_V1
}

/** The renter's answer to the age-range question (`bands_v1`). Nothing is pre-selected and no date of birth is asked. */
enum class LegalAgeChoice(val label: String) {
    Under13("Under 13"),
    Thirteen("13"),
    FourteenToSeventeen("14 to 17"),
    Adult("18 or older"),
    ;

    /**
     * The range the server records, or null when MoveMark isn't available yet (under 13; 13 in Quebec) or the Quebec
     * question is still unanswered ([livesInQuebec] null).
     */
    fun band(livesInQuebec: Boolean?): LegalAgeBand? = when (this) {
        Under13 -> null
        Thirteen -> if (livesInQuebec == false) LegalAgeBand.Teen else null
        FourteenToSeventeen -> LegalAgeBand.Teen
        Adult -> LegalAgeBand.Adult
    }

    /** Phase 1 can't serve this answer (parental consent is Phase 2). */
    fun isUnavailable(livesInQuebec: Boolean?): Boolean = this == Under13 || (this == Thirteen && livesInQuebec == true)

    companion object {
        /** `legal_gate_settings.age_requirement` for the age-range question (migration 1055's default). */
        const val BANDS_V1 = "bands_v1"
    }
}

enum class LegalAgeBand(val raw: String) {
    Teen("13_17"),
    Adult("18_plus"),
}

/** The JSON body of `rpc accept_legal_documents` for this status, or why there is none. */
sealed interface LegalAcceptanceCall {
    data class Send(val params: JsonObject) : LegalAcceptanceCall

    /** The server requires an age statement this build doesn't know. */
    data object UpdateRequired : LegalAcceptanceCall

    /** No eligible range chosen (or no documents): nothing to send. */
    data object NotReady : LegalAcceptanceCall

    companion object {
        /**
         * A server without 1055 (no `age_requirement`) gets the three-argument call. `bands_v1` gets the five-argument
         * call with the chosen range; under enforcement only that call opens the gate. Anything else is an app update.
         */
        fun make(status: LegalStatus, method: String, band: LegalAgeBand?): LegalAcceptanceCall {
            val documents = status.documents ?: return NotReady
            if (status.requiresAppUpdate) return UpdateRequired
            if (status.ageRequirement != null && band == null) return NotReady
            return Send(
                buildJsonObject {
                    put("p_method", method)
                    put("p_terms_version", documents.terms.version)
                    put("p_privacy_notice_version", documents.privacyNotice.version)
                    if (status.ageRequirement != null && band != null) {
                        put("p_age_attestation", status.ageRequirement)
                        put("p_age_band", band.raw)
                    }
                },
            )
        }
    }
}

@Singleton
class LegalRepository @Inject constructor(private val postgrest: PostgrestClient) {
    /** Null when the server has no gate or can't be reached: this only offers the step, the server enforces it. */
    suspend fun status(): LegalStatus? =
        runCatching { postgrest.rpc("get_legal_status", LegalStatus.serializer()) }.getOrNull()

    suspend fun accept(params: JsonObject): LegalStatus =
        postgrest.rpc("accept_legal_documents", LegalStatus.serializer(), params)
}
