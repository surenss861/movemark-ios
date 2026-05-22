package com.surensureshkumar.movemark.core.navigation

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/** One-shot tab switches requested from routes outside [MainShellScreen]. */
@Singleton
class MainTabRequest @Inject constructor() {
    private val _pendingTab = MutableStateFlow<MainTab?>(null)
    val pendingTab: StateFlow<MainTab?> = _pendingTab.asStateFlow()

    fun request(tab: MainTab) {
        _pendingTab.value = tab
    }

    fun clear() {
        _pendingTab.value = null
    }
}
