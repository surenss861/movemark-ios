package com.surensureshkumar.movemark.features.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MainShellViewModel @Inject constructor(
    sessionManager: SessionManager,
    propertyStore: PropertyStore,
) : ViewModel() {
    init {
        viewModelScope.launch {
            sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
        }
    }
}
