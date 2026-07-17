package com.surensureshkumar.movemark.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.auth.ProfileRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _savedSuccessfully = MutableStateFlow(false)
    val savedSuccessfully: StateFlow<Boolean> = _savedSuccessfully.asStateFlow()

    fun saveName(name: String, onSuccess: () -> Unit) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) {
            _errorMessage.value = "Enter your name to continue."
            return
        }
        viewModelScope.launch {
            _isSaving.value = true
            _errorMessage.value = null
            try {
                val userId = sessionManager.userId.value
                    ?: throw IllegalStateException("Sign in to continue.")
                profileRepository.updateFullName(userId, trimmed)
                sessionManager.updateProfileFullName(trimmed)
                _savedSuccessfully.value = true
                onSuccess()
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Couldn't save your name. Try again."
            } finally {
                _isSaving.value = false
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
