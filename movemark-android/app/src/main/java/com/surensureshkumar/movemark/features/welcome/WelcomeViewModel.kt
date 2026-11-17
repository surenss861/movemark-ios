package com.surensureshkumar.movemark.features.welcome

import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.core.startup.FirstRunStatus
import com.surensureshkumar.movemark.core.startup.ProfileStatus
import com.surensureshkumar.movemark.core.startup.RentalStatus
import com.surensureshkumar.movemark.core.startup.StartupCoordinator
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import androidx.lifecycle.viewModelScope
import javax.inject.Inject

/** The launch gates' inputs for the nav host; the decision itself is StartupRouter, the re-checks StartupCoordinator. */
@HiltViewModel
class WelcomeViewModel @Inject constructor(
    sessionManager: SessionManager,
    propertyStore: PropertyStore,
    private val coordinator: StartupCoordinator,
) : ViewModel() {
    val authState: StateFlow<AuthState> = sessionManager.authState
    val profileStatus: StateFlow<ProfileStatus> = sessionManager.profile
        .map { it.status }
        .stateIn(viewModelScope, SharingStarted.Eagerly, sessionManager.profile.value.status)
    val rentalStatus: StateFlow<RentalStatus> = propertyStore.rentalStatus
    val firstRun: StateFlow<FirstRunStatus> = coordinator.firstRun
    val rechecking: StateFlow<Boolean> = coordinator.rechecking
    val legalRecheck: SharedFlow<Unit> = coordinator.legalRecheck

    fun recheck() = coordinator.recheck()

    fun refreshFirstRunState() = coordinator.refreshFirstRun()

    fun markFirstRunComplete() = coordinator.markFirstRunComplete()
}
