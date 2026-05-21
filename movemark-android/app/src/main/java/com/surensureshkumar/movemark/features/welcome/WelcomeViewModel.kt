package com.surensureshkumar.movemark.features.welcome

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor(
    sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
) : ViewModel() {
    val authState: StateFlow<AuthState> = sessionManager.authState

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

    init {
        viewModelScope.launch {
            sessionManager.authState.collect { state ->
                if (state == AuthState.SignedIn) {
                    sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
                }
            }
        }
    }
}
