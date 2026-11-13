/**
 * @file Whether the signed-in renter must pass the legal step, and recording their decision (with the age range the
 *       server asks for). Also where the account's photo rule is learned: `age_category` from every status answer.
 * @domain onboarding-auth
 * @status wip
 * @see [[LegalRepository.kt]]
 * @see [[SessionManager.swift]] — iOS `enter`, `recheckLegalStatus`, `acceptLegalDocuments`
 */
package com.surensureshkumar.movemark.features.legal

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.backend.PostgrestException
import com.surensureshkumar.movemark.data.evidence.PhotoPrivacyStore
import com.surensureshkumar.movemark.data.legal.LegalAcceptanceCall
import com.surensureshkumar.movemark.data.legal.LegalAgeBand
import com.surensureshkumar.movemark.data.legal.LegalAgeRequirement
import com.surensureshkumar.movemark.data.legal.LegalDocuments
import com.surensureshkumar.movemark.data.legal.LegalRepository
import com.surensureshkumar.movemark.data.legal.LegalStatus
import com.surensureshkumar.movemark.data.legal.LegalStatusFailure
import com.surensureshkumar.movemark.data.legal.LegalStatusResult
import com.surensureshkumar.movemark.features.auth.social.SocialBrowserSession
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class LegalGateState(
    /** Null until the server has answered for this session. */
    val required: Boolean? = null,
    val documents: LegalDocuments? = null,
    /** The server's `age_requirement`: null (a server without 1055) means no age question. */
    val ageRequirement: String? = null,
    val isSaving: Boolean = false,
    val error: String? = null,
    /** The server refused with LEGAL_REGION_NOT_AVAILABLE: show the Quebec stop (the app itself never sends "Yes"). */
    val regionRefused: Boolean = false,
    /** The server answered the status with an error: "Can't open your Vault yet" with a retry, never the Vault. */
    val statusUnavailable: Boolean = false,
    val isRetrying: Boolean = false,
) {
    /** The statement this build understands; null with no age code, or with one this build doesn't know. */
    val age: LegalAgeRequirement? get() = ageRequirement?.let(LegalAgeRequirement::fromCode)

    /** The Quebec and age-range questions (bands_v2, bands_v1). */
    val asksAgeRange: Boolean get() = age?.isRangeQuestion == true

    /** A single-box statement (age_13_qc_14, age_18). */
    val asksSingleBox: Boolean get() = age != null && !asksAgeRange

    /** The server asks for an age statement this build doesn't know: Continue can't work, the app must update. */
    val requiresAppUpdate: Boolean get() = ageRequirement != null && age == null

    companion object {
        fun from(status: LegalStatus?, error: String? = null) = LegalGateState(
            // No answer (a server without the gate, or unreachable) opens the app: the server enforces, not this.
            required = status?.needsAcceptance == true,
            documents = status?.documents,
            ageRequirement = status?.ageRequirement,
            error = error,
        )

        /** Where a failed status read lands (iOS `SessionManager.enter`). */
        fun from(result: LegalStatusResult): LegalGateState = when (result) {
            is LegalStatusResult.Success -> from(result.status)
            is LegalStatusResult.Failure -> when (result.reason) {
                // No gate on the server, or offline: open on the cache; the server enforces, not this.
                LegalStatusFailure.ServerWithoutGate, LegalStatusFailure.Offline -> from(null)
                LegalStatusFailure.Unavailable -> LegalGateState(required = null, statusUnavailable = true)
            }
        }
    }
}

@HiltViewModel
class LegalGateViewModel @Inject constructor(
    private val repository: LegalRepository,
    private val sessionManager: SessionManager,
    private val photoPrivacy: PhotoPrivacyStore,
) : ViewModel() {
    private val _state = MutableStateFlow(LegalGateState())
    val state: StateFlow<LegalGateState> = _state.asStateFlow()
    private var lastStatus: LegalStatus? = null
    private var rechecking = false

    /** At sign-in: this account's cached photo rule first, then the server's answer. */
    fun refresh() {
        viewModelScope.launch {
            sessionManager.userId.value?.let { photoPrivacy.restore(it.toString()) }
            enter()
        }
    }

    /** "Try again" on the status-unavailable screen. */
    fun retryStatus() {
        if (!_state.value.statusUnavailable || _state.value.isRetrying) return
        _state.value = _state.value.copy(isRetrying = true)
        viewModelScope.launch { enter() }
    }

    private suspend fun enter() {
        val result = repository.statusResult(retries = 1)
        val status = (result as? LegalStatusResult.Success)?.status
        learnPhotoRule(status)
        lastStatus = status
        _state.value = LegalGateState.from(result)
    }

    /**
     * On return to the foreground and on the API's `LEGAL_ACCEPTANCE_REQUIRED`: a document published (or enforcement
     * turned on) while the app was open shows the gate now. Any failure leaves the renter where they are, and the
     * gate itself is never re-rendered under the renter's answers.
     */
    fun recheck() {
        if (rechecking || _state.value.required != false) return
        rechecking = true
        viewModelScope.launch {
            try {
                val status = repository.status() ?: return@launch
                learnPhotoRule(status)
                if (status.needsAcceptance && _state.value.required == false) {
                    lastStatus = status
                    _state.value = LegalGateState.from(status)
                }
            } finally {
                rechecking = false
            }
        }
    }

    fun reset() {
        lastStatus = null
        photoPrivacy.reset()
        _state.value = LegalGateState()
    }

    /** [band] is the chosen range for the age-range question; null on a server without it. */
    fun accept(band: LegalAgeBand?) {
        val status = lastStatus ?: return
        if (_state.value.isSaving) return
        val params = when (val call = LegalAcceptanceCall.make(status, SocialBrowserSession.lastMethod, band)) {
            is LegalAcceptanceCall.Send -> call.params
            LegalAcceptanceCall.UpdateRequired -> {
                _state.value = _state.value.copy(error = UPDATE_APP)
                return
            }
            LegalAcceptanceCall.NotReady -> return
        }
        _state.value = _state.value.copy(isSaving = true, error = null)
        viewModelScope.launch {
            runCatching { acceptRetryingAuthOnce(params) }
                .onSuccess { accepted ->
                    if (!accepted.needsAcceptance) learnPhotoRule(accepted)
                    lastStatus = accepted
                    _state.value = LegalGateState.from(accepted, error = if (accepted.needsAcceptance) UPDATED else null)
                }
                .onFailure { failure ->
                    val text = serverText(failure)
                    when (val next = classify(text)) {
                        AcceptFailure.RegionNotAvailable ->
                            _state.value = _state.value.copy(isSaving = false, regionRefused = true, error = null)
                        AcceptFailure.AgeChanged, AcceptFailure.DocumentsChanged -> {
                            val current = repository.status()
                            if (current != null) {
                                lastStatus = current
                                _state.value = LegalGateState.from(
                                    current,
                                    error = if (next == AcceptFailure.AgeChanged) AGE_CHANGED else UPDATED,
                                )
                            } else {
                                _state.value = _state.value.copy(isSaving = false, error = NOT_SAVED)
                            }
                        }
                        AcceptFailure.Other -> _state.value = _state.value.copy(isSaving = false, error = NOT_SAVED)
                    }
                }
        }
    }

    /** A one-off LEGAL_NOT_AUTHENTICATED (a token that lapsed in flight) is retried once; a second one is an error. */
    private suspend fun acceptRetryingAuthOnce(params: kotlinx.serialization.json.JsonObject): LegalStatus =
        try {
            repository.accept(params)
        } catch (e: Exception) {
            if (e is kotlinx.coroutines.CancellationException || !serverText(e).contains("LEGAL_NOT_AUTHENTICATED")) throw e
            repository.accept(params)
        }

    private suspend fun learnPhotoRule(status: LegalStatus?) {
        val userId = sessionManager.userId.value ?: return
        if (status != null) photoPrivacy.apply(status.ageCategory, userId.toString())
    }

    enum class AcceptFailure { RegionNotAvailable, AgeChanged, DocumentsChanged, Other }

    companion object {
        /** What a refused acceptance means for the screen (the `RAISE` text from migrations 1030/1055/1057). */
        fun classify(text: String): AcceptFailure = when {
            text.contains("LEGAL_REGION_NOT_AVAILABLE") -> AcceptFailure.RegionNotAvailable
            text.contains("LEGAL_REGION_REQUIRED") || text.contains("LEGAL_AGE_ATTESTATION") ||
                text.contains("LEGAL_AGE_BAND") -> AcceptFailure.AgeChanged
            text.contains("LEGAL_VERSION_NOT_ACTIVE") -> AcceptFailure.DocumentsChanged
            else -> AcceptFailure.Other
        }

        const val UPDATED = "These documents were just updated. Please review them and agree again."
        const val AGE_CHANGED = "The age requirement just changed. Please review it and confirm again."
        const val UPDATE_APP = "Update MoveMark from the Play Store to continue."
        const val NOT_SAVED = "Couldn’t save your agreement. Check your connection and try again."

        /** The Data API puts the function's `RAISE` text in `message`; match on it, not on the exception's own text. */
        fun serverText(failure: Throwable): String =
            listOfNotNull((failure as? PostgrestException)?.serverMessage, failure.message).joinToString(" ")
    }
}
