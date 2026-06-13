package com.surensureshkumar.movemark.features.firstrun

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.firstrun.FirstRunProofPreferences
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FirstRunRoomPickerViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
    private val firstRunPreferences: FirstRunProofPreferences,
) : ViewModel() {

    private val _property = MutableStateFlow<PropertyRecord?>(null)
    val property: StateFlow<PropertyRecord?> = _property.asStateFlow()

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        viewModelScope.launch {
            _loading.value = true
            val userId = sessionManager.userId.value
            if (userId == null) {
                _error.value = "Sign in to continue."
                _loading.value = false
                return@launch
            }
            runCatching {
                if (!propertyStore.hasCompletedInitialFetch.value) {
                    propertyStore.fetchAll(userId)
                }
                _property.value = propertyStore.currentProperty.value
            }.onFailure {
                _error.value = it.message ?: "Couldn't load your rental."
            }
            _loading.value = false
        }
    }

    fun markFirstRunComplete(onDone: () -> Unit) {
        viewModelScope.launch {
            val userId = sessionManager.userId.value ?: return@launch
            firstRunPreferences.markComplete(userId.toString())
            onDone()
        }
    }
}
