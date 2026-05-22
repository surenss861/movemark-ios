package com.surensureshkumar.movemark.features.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.navigation.MainTab
import com.surensureshkumar.movemark.core.navigation.MainTabRequest
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MainShellViewModel @Inject constructor(
    sessionManager: SessionManager,
    propertyStore: PropertyStore,
    private val mainTabRequest: MainTabRequest,
) : ViewModel() {
    val pendingTab: StateFlow<MainTab?> = mainTabRequest.pendingTab

    fun clearTabRequest() = mainTabRequest.clear()
    init {
        viewModelScope.launch {
            sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
        }
    }
}
