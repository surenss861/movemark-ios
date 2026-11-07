/**
 * @file Whether the signed-in renter must pass the legal step, and recording their decision.
 * @domain onboarding-auth
 * @status wip
 * @see [[LegalRepository.kt]]
 */
package com.surensureshkumar.movemark.features.legal

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.legal.LegalDocuments
import com.surensureshkumar.movemark.data.legal.LegalRepository
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
    val isSaving: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class LegalGateViewModel @Inject constructor(private val repository: LegalRepository) : ViewModel() {
    private val _state = MutableStateFlow(LegalGateState())
    val state: StateFlow<LegalGateState> = _state.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            val status = repository.status()
            _state.value = LegalGateState(
                required = status?.needsAcceptance == true,
                documents = status?.documents,
            )
        }
    }

    fun reset() {
        _state.value = LegalGateState()
    }

    fun accept() {
        val documents = _state.value.documents ?: return
        if (_state.value.isSaving) return
        _state.value = _state.value.copy(isSaving = true, error = null)
        viewModelScope.launch {
            runCatching { repository.accept(SocialBrowserSession.lastMethod, documents) }
                .onSuccess { status ->
                    _state.value = LegalGateState(
                        required = status.needsAcceptance,
                        documents = status.documents,
                        error = if (status.needsAcceptance) UPDATED else null,
                    )
                }
                .onFailure { failure ->
                    if (failure.message.orEmpty().contains("LEGAL_VERSION_NOT_ACTIVE")) {
                        val status = repository.status()
                        _state.value = LegalGateState(
                            required = status?.needsAcceptance == true,
                            documents = status?.documents,
                            error = UPDATED,
                        )
                    } else {
                        _state.value = _state.value.copy(
                            isSaving = false,
                            error = "Couldn’t save your agreement. Check your connection and try again.",
                        )
                    }
                }
        }
    }

    private companion object {
        const val UPDATED = "These documents were just updated. Please review them and agree again."
    }
}
