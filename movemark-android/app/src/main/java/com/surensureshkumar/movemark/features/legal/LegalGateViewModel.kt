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
import com.surensureshkumar.movemark.data.legal.LegalAgeChoice
import com.surensureshkumar.movemark.data.legal.LegalDocuments
import com.surensureshkumar.movemark.data.legal.LegalRepository
import com.surensureshkumar.movemark.data.legal.LegalStatus
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
) {
    /** The server asks for the age-range question this build knows. */
    val asksAgeRange: Boolean get() = ageRequirement == LegalAgeChoice.BANDS_V1

    /** The server asks for an age statement this build doesn't know: Continue can't work, the app must update. */
    val requiresAppUpdate: Boolean get() = ageRequirement != null && !asksAgeRange

    companion object {
        fun from(status: LegalStatus?, error: String? = null) = LegalGateState(
            // No answer (a server without the gate, or unreachable) opens the app: the server enforces, not this.
            required = status?.needsAcceptance == true,
            documents = status?.documents,
            ageRequirement = status?.ageRequirement,
            error = error,
        )
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
            val status = repository.status()
            learnPhotoRule(status)
            lastStatus = status
            _state.value = LegalGateState.from(status)
        }
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
            runCatching { repository.accept(params) }
                .onSuccess { accepted ->
                    if (!accepted.needsAcceptance) learnPhotoRule(accepted)
                    lastStatus = accepted
                    _state.value = LegalGateState.from(accepted, error = if (accepted.needsAcceptance) UPDATED else null)
                }
                .onFailure { failure ->
                    val text = serverText(failure)
                    val ageChanged = text.contains("LEGAL_AGE_ATTESTATION") || text.contains("LEGAL_AGE_BAND")
                    val current = if (ageChanged || text.contains("LEGAL_VERSION_NOT_ACTIVE")) repository.status() else null
                    if (current != null) {
                        lastStatus = current
                        _state.value = LegalGateState.from(current, error = if (ageChanged) AGE_CHANGED else UPDATED)
                    } else {
                        _state.value = _state.value.copy(isSaving = false, error = NOT_SAVED)
                    }
                }
        }
    }

    private suspend fun learnPhotoRule(status: LegalStatus?) {
        val userId = sessionManager.userId.value ?: return
        if (status != null) photoPrivacy.apply(status.ageCategory, userId.toString())
    }

    companion object {
        const val UPDATED = "These documents were just updated. Please review them and agree again."
        const val AGE_CHANGED = "The age requirement just changed. Please review it and confirm again."
        const val UPDATE_APP = "Update MoveMark from Google Play to continue."
        const val NOT_SAVED = "Couldn’t save your agreement. Check your connection and try again."

        /** The Data API puts the function's `RAISE` text in `message`; match on it, not on the exception's own text. */
        fun serverText(failure: Throwable): String =
            listOfNotNull((failure as? PostgrestException)?.serverMessage, failure.message).joinToString(" ")
    }
}
