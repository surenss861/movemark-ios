package com.surensureshkumar.movemark.features.welcome

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.firstrun.FirstRunProofPreferences
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val firstRunPreferences: FirstRunProofPreferences,
) : ViewModel() {
    val authState: StateFlow<AuthState> = sessionManager.authState

    private val _firstRunComplete = MutableStateFlow<Boolean?>(null)
    val firstRunComplete: StateFlow<Boolean?> = _firstRunComplete.asStateFlow()

    val hasProperty: StateFlow<Boolean?> = combine(
        sessionManager.authState,
        propertyStore.hasCompletedInitialFetch,
        propertyStore.currentProperty,
    ) { auth, fetched, property ->
        when {
            auth != AuthState.SignedIn -> null
            !fetched -> null
            property != null -> true
            else -> false
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val needsOnboarding: StateFlow<Boolean?> = combine(
        sessionManager.authState,
        sessionManager.hasFetchedProfile,
        sessionManager.userFullName,
    ) { auth, fetchedProfile, fullName ->
        when {
            auth != AuthState.SignedIn -> null
            !fetchedProfile -> null
            else -> fullName.isNullOrBlank()
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    init {
        viewModelScope.launch {
            sessionManager.authState.collect { state ->
                if (state == AuthState.SignedIn) {
                    sessionManager.userId.value?.let { userId ->
                        propertyStore.fetchAll(userId)
                        _firstRunComplete.value = firstRunPreferences.isComplete(userId.toString())
                    }
                } else {
                    _firstRunComplete.value = null
                }
            }
        }
    }

    fun refreshFirstRunState() {
        viewModelScope.launch {
            sessionManager.userId.value?.let { userId ->
                _firstRunComplete.value = firstRunPreferences.isComplete(userId.toString())
            }
        }
    }

    fun markFirstRunComplete() {
        viewModelScope.launch {
            sessionManager.userId.value?.let { userId ->
                firstRunPreferences.markComplete(userId.toString())
                _firstRunComplete.value = true
            }
        }
    }
}
