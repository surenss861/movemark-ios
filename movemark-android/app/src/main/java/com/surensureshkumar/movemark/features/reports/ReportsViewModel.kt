package com.surensureshkumar.movemark.features.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.export.ExportRepository
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.data.export.ReportReadinessMapper
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import com.surensureshkumar.movemark.features.reports.components.ChecklistItemState
import com.surensureshkumar.movemark.features.reports.components.ReportChecklistItem
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class ReportsUiState(
    val propertyLoading: Boolean = true,
    val exportsLoading: Boolean = false,
    val noVault: Boolean = false,
    val readiness: ReportReadiness = ReportReadiness.NoVault,
    val documentedRooms: Int = 0,
    val totalRooms: Int = 0,
    val totalPhotos: Int = 0,
    val proofChips: List<String> = emptyList(),
    val checklistItems: List<ReportChecklistItem> = emptyList(),
    val exports: List<ExportRow> = emptyList(),
    val actionInProgress: Boolean = false,
    val banner: String? = null,
    val bannerIsError: Boolean = false,
)

@HiltViewModel
class ReportsViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val exportRepository: ExportRepository,
) : ViewModel() {

    private val _exports = MutableStateFlow<List<ExportRow>>(emptyList())
    private val _exportsLoading = MutableStateFlow(false)
    private val _actionInProgress = MutableStateFlow(false)
    private val _banner = MutableStateFlow<Pair<String, Boolean>?>(null)

    private val _uiState = MutableStateFlow(ReportsUiState())
    val uiState: StateFlow<ReportsUiState> = _uiState.asStateFlow()

    private val _shareUrl = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val shareUrl: SharedFlow<String> = _shareUrl.asSharedFlow()

    init {
        viewModelScope.launch {
            combine(
                combine(
                    propertyStore.currentProperty,
                    propertyStore.isLoading,
                    _exports,
                ) { property, loading, exports -> Triple(property, loading, exports) },
                combine(_exportsLoading, _actionInProgress, _banner) { exportsLoading, actionBusy, banner ->
                    Triple(exportsLoading, actionBusy, banner)
                },
            ) { left, right ->
                buildUiState(
                    property = left.first,
                    propertyLoading = left.second,
                    exports = left.third,
                    exportsLoading = right.first,
                    actionBusy = right.second,
                    banner = right.third,
                )
            }.collect { _uiState.value = it }
        }
        viewModelScope.launch {
            propertyStore.currentProperty.collect { property ->
                if (property != null) {
                    refreshExports()
                } else {
                    _exports.value = emptyList()
                }
            }
        }
    }

    fun refreshExports() {
        val property = propertyStore.currentProperty.value ?: return
        viewModelScope.launch {
            _exportsLoading.value = true
            _banner.value = null
            try {
                _exports.value = withContext(Dispatchers.IO) {
                    exportRepository.loadExports(property.id)
                }
            } catch (e: Exception) {
                _banner.value = exportRepository.userMessage(e) to true
                _exports.value = emptyList()
            } finally {
                _exportsLoading.value = false
            }
        }
    }

    fun onPrimaryAction(onContinueRoomProof: () -> Unit) {
        when (_uiState.value.readiness) {
            ReportReadiness.NotReady, ReportReadiness.NoVault -> onContinueRoomProof()
            ReportReadiness.ReadyToMake -> queueMoveInReport()
            ReportReadiness.ReadyToShare -> shareReadyReport()
            ReportReadiness.Failed -> queueMoveInReport()
            ReportReadiness.Processing -> Unit
        }
    }

    private fun queueMoveInReport() {
        val property = propertyStore.currentProperty.value ?: return
        if (_actionInProgress.value) return
        if (ReportReadinessMapper.hasActiveMoveInJob(_exports.value)) {
            _banner.value = "A move-in report is already building. Check status below." to false
            return
        }
        viewModelScope.launch {
            _actionInProgress.value = true
            _banner.value = null
            try {
                withContext(Dispatchers.IO) {
                    exportRepository.queueMoveInReport(property.id)
                }
                _banner.value = "Report queued. Building your PDF…" to false
                refreshExports()
            } catch (e: Exception) {
                _banner.value = exportRepository.userMessage(e) to true
            } finally {
                _actionInProgress.value = false
            }
        }
    }

    private fun shareReadyReport() {
        val row = ReportReadinessMapper.firstReadyExport(_exports.value) ?: return
        if (_actionInProgress.value) return
        viewModelScope.launch {
            _actionInProgress.value = true
            _banner.value = null
            try {
                val url = withContext(Dispatchers.IO) {
                    exportRepository.downloadUrl(row.id)
                }
                _shareUrl.emit(url)
            } catch (e: Exception) {
                _banner.value = exportRepository.userMessage(e) to true
            } finally {
                _actionInProgress.value = false
            }
        }
    }

    private fun buildUiState(
        property: PropertyRecord?,
        propertyLoading: Boolean,
        exports: List<ExportRow>,
        exportsLoading: Boolean,
        actionBusy: Boolean,
        banner: Pair<String, Boolean>?,
    ): ReportsUiState {
        if (propertyLoading && property == null) {
            return ReportsUiState(propertyLoading = true, exportsLoading = exportsLoading)
        }
        if (property == null) {
            return ReportsUiState(
                propertyLoading = false,
                noVault = true,
                readiness = ReportReadiness.NoVault,
                exportsLoading = exportsLoading,
                banner = banner?.first,
                bannerIsError = banner?.second == true,
            )
        }
        val documented = RoomProofMetrics.documentedCount(property)
        val total = property.rooms.size
        val photos = RoomProofMetrics.totalPhotoCount(property)
        val readiness = ReportReadinessMapper.resolve(
            hasVault = true,
            documentedRooms = documented,
            exports = exports,
        )
        return ReportsUiState(
            propertyLoading = false,
            exportsLoading = exportsLoading,
            noVault = false,
            readiness = readiness,
            documentedRooms = documented,
            totalRooms = total,
            totalPhotos = photos,
            proofChips = buildProofChips(documented, total, photos),
            checklistItems = buildChecklist(documented, total, readiness),
            exports = exports,
            actionInProgress = actionBusy,
            banner = banner?.first,
            bannerIsError = banner?.second == true,
        )
    }

    private fun buildProofChips(documented: Int, total: Int, photos: Int): List<String> {
        val chips = mutableListOf<String>()
        if (total > 0) chips += "$documented/$total rooms"
        if (photos > 0) chips += if (photos == 1) "1 photo" else "$photos photos"
        return chips
    }

    private fun buildChecklist(
        documented: Int,
        total: Int,
        readiness: ReportReadiness,
    ): List<ReportChecklistItem> {
        val roomsState = when {
            total == 0 || documented == 0 -> ChecklistItemState.Incomplete
            documented >= total -> ChecklistItemState.Complete
            else -> ChecklistItemState.Incomplete
        }
        val reportState = when (readiness) {
            ReportReadiness.ReadyToMake, ReportReadiness.ReadyToShare, ReportReadiness.Processing ->
                ChecklistItemState.Complete
            ReportReadiness.Failed -> ChecklistItemState.Incomplete
            else -> ChecklistItemState.Locked
        }
        return listOf(
            ReportChecklistItem(
                title = "Room photos",
                detail = if (total == 0) "Add rooms in your vault" else "$documented of $total rooms ready",
                state = roomsState,
            ),
            ReportChecklistItem(
                title = "Lease & docs",
                detail = "Optional on Android — add on iOS for stronger reports",
                state = ChecklistItemState.Locked,
            ),
            ReportChecklistItem(
                title = "Report",
                detail = when (readiness) {
                    ReportReadiness.ReadyToMake -> "Can make from saved proof"
                    ReportReadiness.ReadyToShare -> "Ready to view or share"
                    ReportReadiness.Processing -> "Building from saved proof"
                    ReportReadiness.Failed -> "Last report failed — retry when ready"
                    else -> "Unlocks after room proof"
                },
                state = reportState,
            ),
        )
    }
}

private fun primaryCta(readiness: ReportReadiness, loading: Boolean, busy: Boolean): Triple<String, Boolean, Boolean> {
    if (loading) return Triple("Checking report…", false, false)
    return when (readiness) {
        ReportReadiness.NotReady, ReportReadiness.NoVault -> Triple("Continue room proof", true, false)
        ReportReadiness.ReadyToMake -> Triple(if (busy) "Making report…" else "Make move-in report", !busy, busy)
        ReportReadiness.ReadyToShare -> Triple(if (busy) "Opening…" else "View / Share report", !busy, busy)
        ReportReadiness.Processing -> Triple("Building…", false, false)
        ReportReadiness.Failed -> Triple(if (busy) "Retrying…" else "Retry report", !busy, busy)
    }
}

fun ReportsUiState.heroHeadline(): String = when (readiness) {
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Finish room proof first."
    ReportReadiness.ReadyToMake -> "You can make a report now."
    ReportReadiness.ReadyToShare -> "Your report is ready to share."
    ReportReadiness.Processing -> "Building your PDF report."
    ReportReadiness.Failed -> "We couldn't finish your report."
}

fun ReportsUiState.heroFootnote(): String? = when (readiness) {
    ReportReadiness.NotReady, ReportReadiness.NoVault ->
        "Complete each room before creating your report."
    ReportReadiness.ReadyToMake -> "Add more rooms for a stronger report."
    else -> null
}

fun ReportsUiState.metricsLine(): String? {
    if (propertyLoading || exportsLoading) return null
    val parts = mutableListOf<String>()
    if (totalRooms > 0) parts += "$documentedRooms of $totalRooms rooms ready"
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}

fun ReportsUiState.primaryCta(): Triple<String, Boolean, Boolean> =
    primaryCta(readiness, propertyLoading || exportsLoading, actionInProgress)
