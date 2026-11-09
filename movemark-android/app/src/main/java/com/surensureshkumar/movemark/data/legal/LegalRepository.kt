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
import kotlinx.serialization.json.JsonPrimitive
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

    /** The statement this build understands, or null (no gate age code, or one this build doesn't know). */
    val age: LegalAgeRequirement? get() = ageRequirement?.let(LegalAgeRequirement::fromCode)

    /** True when the server requires an age statement this build doesn't know: the renter must update the app. */
    val requiresAppUpdate: Boolean get() = ageRequirement != null && age == null
}

/** The statements the server may require (`legal_gate_settings.age_requirement`). No date of birth is asked or kept. */
enum class LegalAgeRequirement(val code: String) {
    /**
     * Migration 1057's default: "Do you live in Quebec?" first, then the age range. Quebec isn't served at the initial
     * launch (no French versions yet), so "Yes" stops at any age. Temporary: French support replaces this code.
     */
    BandsV2("bands_v2"),

    /** Migration 1055: the age range alone. This build asks the Quebec question here too and stops a "Yes" on the device. */
    BandsV1("bands_v1"),
    Age13Qc14("age_13_qc_14"),
    Age18("age_18"),
    ;

    /** The Quebec + age-range questions, rather than a single box. */
    val isRangeQuestion: Boolean get() = this == BandsV2 || this == BandsV1

    /** The single box's statement (the range codes use the questions instead). */
    val confirmation: String get() = when (this) {
        Age13Qc14 -> "I’m 13 or older (14 or older if I live in Quebec)."
        Age18 -> "I’m 18 or older."
        else -> "How old are you?"
    }

    val explanation: String get() = when (this) {
        Age13Qc14 -> "MoveMark isn’t for children under 13 (under 14 in Quebec). If you’re under 18: your photos, documents and rental details are stored in the United States, nobody else sees them unless you share a report, and you can delete everything from Account at any time."
        Age18 -> "MoveMark is for adults. Your photos, documents and rental details are stored in the United States, nobody else sees them unless you share a report, and you can delete everything from Account at any time."
        else -> "MoveMark asks for your age range only, never your date of birth."
    }

    companion object {
        fun fromCode(code: String): LegalAgeRequirement? = entries.firstOrNull { it.code == code }
    }
}

/** The renter's answer to the age-range question. Nothing is pre-selected and no date of birth is asked. */
enum class LegalAgeChoice(val label: String) {
    Under13("Under 13"),
    Thirteen("13"),
    FourteenToSeventeen("14 to 17"),
    Adult("18 or older"),
    ;

    /**
     * The range the server records, or null when there is nothing to record: the Quebec question unanswered
     * ([livesInQuebec] null) or answered "Yes" (Quebec isn't served yet, at any age), or under 13.
     */
    fun band(livesInQuebec: Boolean?): LegalAgeBand? {
        if (livesInQuebec != false) return null
        return when (this) {
            Under13 -> null
            Thirteen, FourteenToSeventeen -> LegalAgeBand.Teen
            Adult -> LegalAgeBand.Adult
        }
    }

    fun isUnavailable(livesInQuebec: Boolean?): Boolean = LegalUnavailable.reason(this, livesInQuebec) != null
}

/** Why the agreement screen stops. Nothing is sent to the server for either. */
enum class LegalUnavailable {
    /** "Yes" to "Do you live in Quebec?", at any age. Temporary, until French versions exist. */
    Quebec,

    /** Under 13, outside Quebec (parental consent is Phase 2). */
    Age,
    ;

    companion object {
        fun reason(choice: LegalAgeChoice?, livesInQuebec: Boolean?): LegalUnavailable? = when {
            livesInQuebec == true -> Quebec
            choice == LegalAgeChoice.Under13 -> Age
            else -> null
        }

        const val QUEBEC_MESSAGE =
            "MoveMark isn’t available in Quebec yet. We’re preparing French-language support. Your account hasn’t been set up. You can delete it below."
        const val QUEBEC_SUBSCRIPTION_NOTE = "If you subscribed, cancel in Google Play › Subscriptions."
        const val AGE_MESSAGE =
            "MoveMark isn’t available for you yet. We’re working on a way for a parent or guardian to set it up with you. You can sign out or delete this account below."
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
         * A server without 1055 (no `age_requirement`) gets the three-argument call. `bands_v2` (1057) gets the six-argument
         * call with the range and `p_lives_in_quebec: false`; `bands_v1` the five-argument call; the single-box codes the
         * four-argument call. A code this build doesn't know is an app update.
         */
        fun make(status: LegalStatus, method: String, band: LegalAgeBand?): LegalAcceptanceCall {
            val documents = status.documents ?: return NotReady
            val base = buildJsonObject {
                put("p_method", method)
                put("p_terms_version", documents.terms.version)
                put("p_privacy_notice_version", documents.privacyNotice.version)
            }
            if (status.ageRequirement == null) return Send(base) // a server without 1055: the three-argument call
            val age = status.age ?: return UpdateRequired
            fun with(vararg extra: Pair<String, kotlinx.serialization.json.JsonElement>) =
                Send(JsonObject(base + extra.toMap()))
            return when (age) {
                // A band exists only after "No" to Quebec and an eligible age. "Yes" is never sent.
                LegalAgeRequirement.BandsV2 -> if (band == null) NotReady else with(
                    "p_age_attestation" to JsonPrimitive(age.code),
                    "p_age_band" to JsonPrimitive(band.raw),
                    "p_lives_in_quebec" to JsonPrimitive(false),
                )
                LegalAgeRequirement.BandsV1 -> if (band == null) NotReady else with(
                    "p_age_attestation" to JsonPrimitive(age.code),
                    "p_age_band" to JsonPrimitive(band.raw),
                )
                // The single box (the screen requires it to be ticked): the four-argument call.
                LegalAgeRequirement.Age13Qc14, LegalAgeRequirement.Age18 -> with("p_age_attestation" to JsonPrimitive(age.code))
            }
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
