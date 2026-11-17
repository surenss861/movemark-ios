/**
 * @file Owns the launch gates' inputs for the signed-in account: loads the rental at sign-in, works out the first-room
 *       step, and re-checks whatever couldn't be confirmed when the connection returns, when the app comes back to the
 *       foreground, or when the renter taps "Try again". Routing itself is [StartupRouter] (pure, unit-tested).
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupRouter.kt]]
 * @see [[MoveMarkNavHost.kt]]
 */
package com.surensureshkumar.movemark.core.startup

import android.util.Log
import com.surensureshkumar.movemark.core.network.ConnectivityMonitor
import com.surensureshkumar.movemark.data.auth.AuthState
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.evidence.pending.PendingEvidenceCenter
import com.surensureshkumar.movemark.data.firstrun.FirstRunProofPreferences
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import dagger.Lazy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StartupCoordinator @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val firstRunPreferences: FirstRunProofPreferences,
    private val pendingEvidence: Lazy<PendingEvidenceCenter>,
    private val profileRepository: com.surensureshkumar.movemark.data.auth.ProfileRepository,
    connectivity: ConnectivityMonitor,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _firstRun = MutableStateFlow(FirstRunStatus.Unknown)
    val firstRun: StateFlow<FirstRunStatus> = _firstRun.asStateFlow()

    private val _rechecking = MutableStateFlow(false)
    val rechecking: StateFlow<Boolean> = _rechecking.asStateFlow()

    private val _legalRecheck = MutableSharedFlow<Unit>(extraBufferCapacity = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    /** The legal gate lives in a ViewModel: the nav host re-checks it when this emits. */
    val legalRecheck: SharedFlow<Unit> = _legalRecheck.asSharedFlow()

    private val recheckLock = Mutex()
    private val firstRunLock = Mutex()

    init {
        scope.launch {
            sessionManager.authState.collect { state ->
                if (state == AuthState.SignedIn) {
                    sessionManager.userId.value?.let { userId ->
                        propertyStore.fetchAll(userId)
                        recomputeFirstRun(userId)
                    }
                } else {
                    _firstRun.value = FirstRunStatus.Unknown
                }
            }
        }
        scope.launch {
            // A rental restored from cache, or loaded after a reconnect, settles the first-room step too.
            combine(propertyStore.rentalStatus, propertyStore.currentProperty) { status, property -> status to property?.id }
                .distinctUntilChanged()
                .collect { sessionManager.userId.value?.let { recomputeFirstRun(it) } }
        }
        scope.launch {
            connectivity.reconnected.collect {
                Log.i(TAG, "connection back; re-checking launch gates")
                recheck()
            }
        }
    }

    /** Re-reads only what this session hasn't confirmed with the server, plus the legal status and pending photos. */
    fun recheck() {
        scope.launch {
            if (!recheckLock.tryLock()) return@launch
            try {
                if (sessionManager.authState.value != AuthState.SignedIn) return@launch
                val userId = sessionManager.userId.value ?: return@launch
                _rechecking.value = true
                _legalRecheck.tryEmit(Unit)
                coroutineScope {
                    launch { sessionManager.refreshProfileIfUnverified() }
                    propertyStore.fetchAllIfUnverified(userId)
                }
                recomputeFirstRun(userId)
                // Photos saved on this phone but not yet confirmed: settle what the reconnect makes possible.
                pendingEvidence.get().reconcileAll(userId.toString())
            } finally {
                _rechecking.value = false
                recheckLock.unlock()
            }
        }
    }

    fun markFirstRunComplete() {
        scope.launch {
            val userId = sessionManager.userId.value ?: return@launch
            firstRunPreferences.markComplete(userId.toString())
            _firstRun.value = FirstRunStatus.Complete
            // Cross-device / iOS: the profile carries it too. Best effort; this device's flag already holds.
            runCatching { profileRepository.markOnboardingCompleted(userId) }
                .onFailure { Log.i(TAG, "onboarding_completed_at not recorded: ${it.javaClass.simpleName}") }
        }
    }

    fun refreshFirstRun() {
        scope.launch { sessionManager.userId.value?.let { recomputeFirstRun(it) } }
    }

    private suspend fun recomputeFirstRun(userId: UUID) {
        firstRunLock.withLock { recomputeFirstRunLocked(userId) }
    }

    private suspend fun recomputeFirstRunLocked(userId: UUID) {
        if (sessionManager.userId.value != userId) return
        // Never step back: once the first room is behind the renter this session, it stays behind.
        if (_firstRun.value == FirstRunStatus.Complete) return
        val local = firstRunPreferences.isComplete(userId.toString())
        val pending = runCatching { pendingEvidence.get().pendingCount(userId.toString()) }.getOrDefault(0)
        val property = propertyStore.currentProperty.value
        val hasProof = property != null && RoomProofMetrics.isFirstRunComplete(false, property)
        val next = StartupRouter.firstRun(propertyStore.rentalStatus.value, local, hasProof, pending)
        // A vault that already has proof (saved on another device) skips the first-room picker here too.
        if (next == FirstRunStatus.Complete && !local && hasProof) firstRunPreferences.markComplete(userId.toString())
        _firstRun.value = next
    }

    private companion object {
        const val TAG = "StartupCoordinator"
    }
}
