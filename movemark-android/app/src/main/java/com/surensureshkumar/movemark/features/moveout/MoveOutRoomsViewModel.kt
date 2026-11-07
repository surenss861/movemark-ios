package com.surensureshkumar.movemark.features.moveout

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.export.ExportRepository
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.ChecklistRepository
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.MoveOutChecklistRow
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.remote.ExportApiException
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import com.surensureshkumar.movemark.domain.MoveOutOverview
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/** Move-out: every room's move-in record beside its move-out record, the closeout checklist, the report (iOS `MoveOutFoundationView`). */
@HiltViewModel
class MoveOutRoomsViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
    private val checklistRepository: ChecklistRepository,
    private val inspectionRepository: InspectionRepository,
    private val exportRepository: ExportRepository,
    private val subscriptionRepository: SubscriptionRepository,
) : ViewModel() {
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val loading: StateFlow<Boolean> = propertyStore.isLoading
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro

    val overview: StateFlow<MoveOutOverview?> = propertyStore.currentProperty
        .map { it?.let { p -> MoveOutOverview(p.rooms) } }
        .stateIn(viewModelScope, SharingStarted.Eagerly, propertyStore.currentProperty.value?.let { MoveOutOverview(it.rooms) })

    /** Rooms that gained move-out photos while this screen was open: what the renter just added. */
    private val _justCompared = MutableStateFlow<Set<UUID>>(emptySet())
    val justCompared: StateFlow<Set<UUID>> = _justCompared.asStateFlow()

    private val _checklist = MutableStateFlow<MoveOutChecklistRow?>(null)
    val checklist: StateFlow<MoveOutChecklistRow?> = _checklist.asStateFlow()

    private val _loadingChecklist = MutableStateFlow(false)
    val loadingChecklist: StateFlow<Boolean> = _loadingChecklist.asStateFlow()

    /** Checklist rows with a save in flight: a second tap waits, so a failed save can't roll back over it. */
    private val savingRows = mutableSetOf<MoveOutChecklistRow.Item>()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    /** The error belongs to the report action (shown beside it, with its own retry). */
    private val _errorFromExport = MutableStateFlow(false)
    val errorFromExport: StateFlow<Boolean> = _errorFromExport.asStateFlow()

    private val _queuedNotice = MutableStateFlow<String?>(null)
    val queuedNotice: StateFlow<String?> = _queuedNotice.asStateFlow()

    private val _exporting = MutableStateFlow(false)
    val exporting: StateFlow<Boolean> = _exporting.asStateFlow()

    private val _paywall = MutableSharedFlow<PaywallReason>(extraBufferCapacity = 1)
    val paywall: SharedFlow<PaywallReason> = _paywall.asSharedFlow()

    init {
        loadChecklist()
        viewModelScope.launch {
            var previous: Set<UUID>? = null
            overview.collect { o ->
                val missing = o?.missingIds ?: return@collect
                previous?.let { old -> _justCompared.value = _justCompared.value + (old - missing) }
                previous = missing
            }
        }
    }

    val rentalName: String
        get() {
            val p = propertyStore.currentProperty.value ?: return "Move-out"
            return p.title.trim().ifEmpty { p.addressLine1 }
        }

    suspend fun signedPhotoUrl(path: String): String? = runCatching { inspectionRepository.signedUrl(path) }.getOrNull()

    fun loadChecklist() {
        val propertyId = propertyStore.currentProperty.value?.id ?: return
        val userId = sessionManager.userId.value ?: return
        viewModelScope.launch {
            _loadingChecklist.value = true
            try {
                _checklist.value = checklistRepository.fetch(propertyId, userId)
                    ?: MoveOutChecklistRow.empty(propertyId, userId).also { checklistRepository.upsert(it) }
                if (!_errorFromExport.value) _error.value = null
            } catch (e: Exception) {
                Log.e(TAG, "checklist load failed", e)
                _error.value = CHECKLIST_FAILED
                _errorFromExport.value = false
            } finally {
                _loadingChecklist.value = false
            }
        }
    }

    /** Toggles and saves one row; a failed save rolls back only that row. */
    fun toggle(item: MoveOutChecklistRow.Item) {
        val current = _checklist.value ?: return
        if (item in savingRows) return
        val wasDone = current.isDone(item)
        val updated = current.with(item, !wasDone)
        _checklist.value = updated
        savingRows += item
        viewModelScope.launch {
            try {
                checklistRepository.upsert(_checklist.value ?: updated)
                if (!_errorFromExport.value) _error.value = null
            } catch (e: Exception) {
                Log.e(TAG, "checklist save failed", e)
                _checklist.value = _checklist.value?.with(item, wasDone)
                _error.value = CHECKLIST_FAILED
                _errorFromExport.value = false
            } finally {
                savingRows -= item
            }
        }
    }

    /** "Generate move-out report": Pro first (the server decides too: 402 opens the paywall). */
    fun generateReport() {
        if (!subscriptionRepository.hasPro.value) {
            _paywall.tryEmit(PaywallReason.MoveOutExport)
            return
        }
        queueReport()
    }

    fun queueReport() {
        val property = propertyStore.currentProperty.value ?: return
        if ((overview.value?.roomsWithMoveOutPhotos ?: 0) == 0 || _exporting.value) return
        viewModelScope.launch {
            _exporting.value = true
            _error.value = null
            _queuedNotice.value = null
            try {
                exportRepository.queueMoveOutReport(property.id)
                _errorFromExport.value = false
                _queuedNotice.value = QUEUED
            } catch (e: ExportApiException.PaymentRequired) {
                subscriptionRepository.refreshCustomerInfo()
                _paywall.tryEmit(PaywallReason.MoveOutExport)
            } catch (e: ExportApiException.AlreadyActive) {
                _errorFromExport.value = false
                _queuedNotice.value = QUEUED
            } catch (e: Exception) {
                _error.value = MMUserMessages.export(e).takeUnless { it.startsWith("Report couldn't complete") }
                    ?: "Couldn't queue move-out report. Try again."
                _errorFromExport.value = true
            } finally {
                _exporting.value = false
            }
        }
    }

    private companion object {
        const val TAG = "MoveOut"
        const val QUEUED = "Report queued — it will appear in Reports when ready"
        const val CHECKLIST_FAILED = "Couldn't save your checklist. Try again."
    }
}
