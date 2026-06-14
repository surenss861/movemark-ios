package com.surensureshkumar.movemark.features.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.export.DisputePacketReadiness
import com.surensureshkumar.movemark.data.export.DisputePacketReadinessMapper
import com.surensureshkumar.movemark.data.export.ExportRepository
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.MoveOutReportReadiness
import com.surensureshkumar.movemark.data.export.MoveOutReportReadinessMapper
import com.surensureshkumar.movemark.data.export.ReportReadiness
import com.surensureshkumar.movemark.data.export.ReportReadinessMapper
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import com.surensureshkumar.movemark.features.reports.components.ChecklistItemState
import com.surensureshkumar.movemark.features.reports.components.ReportChecklistItem
import com.surensureshkumar.movemark.features.subscription.PaywallReason
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
    val moveInActionInProgress: Boolean = false,
    val moveOutActionInProgress: Boolean = false,
    val disputeActionInProgress: Boolean = false,
    val banner: String? = null,
    val bannerIsError: Boolean = false,
    val moveOutPhotos: Int = 0,
    val moveOutDocumentedRooms: Int = 0,
    val moveOutReadiness: MoveOutReportReadiness = MoveOutReportReadiness.NoProof,
    val moveOutReportStatus: String = "Capture move-out proof first.",
    val disputeReadiness: DisputePacketReadiness = DisputePacketReadiness.NoProof,
    val disputePacketStatus: String = "Add room proof first.",
)

@HiltViewModel
class ReportsViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val exportRepository: ExportRepository,
    subscriptionRepository: SubscriptionRepository,
) : ViewModel() {

    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro

    private val _exports = MutableStateFlow<List<ExportRow>>(emptyList())
    private val _exportsLoading = MutableStateFlow(false)
    private val _actionInProgress = MutableStateFlow(false)
    private val _moveOutActionInProgress = MutableStateFlow(false)
    private val _disputeActionInProgress = MutableStateFlow(false)
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
                combine(
                    _exportsLoading,
                    _actionInProgress,
                    _moveOutActionInProgress,
                    _disputeActionInProgress,
                ) { exportsLoading, moveInBusy, moveOutBusy, disputeBusy ->
                    listOf(exportsLoading, moveInBusy, moveOutBusy, disputeBusy)
                },
                _banner,
            ) { propTriple, busyFlags, banner ->
                @Suppress("UNCHECKED_CAST")
                buildUiState(
                    property = propTriple.first,
                    propertyLoading = propTriple.second,
                    exports = propTriple.third,
                    exportsLoading = busyFlags[0] as Boolean,
                    moveInBusy = busyFlags[1] as Boolean,
                    moveOutBusy = busyFlags[2] as Boolean,
                    disputeBusy = busyFlags[3] as Boolean,
                    banner = banner,
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
            ReportReadiness.ReadyToShare -> shareMoveInReport()
            ReportReadiness.Failed -> queueMoveInReport()
            ReportReadiness.Processing -> Unit
        }
    }

    fun onDisputePrimaryAction(
        hasPro: Boolean,
        onContinueRoomProof: () -> Unit,
        onShowPaywall: (PaywallReason) -> Unit,
    ) {
        if (!hasPro) {
            onShowPaywall(PaywallReason.DisputePacket)
            return
        }
        when (_uiState.value.disputeReadiness) {
            DisputePacketReadiness.NoProof -> onContinueRoomProof()
            DisputePacketReadiness.ReadyToMake -> queueDisputePacket()
            DisputePacketReadiness.ReadyToShare -> shareDisputePacket()
            DisputePacketReadiness.Failed -> queueDisputePacket()
            DisputePacketReadiness.Processing -> Unit
        }
    }

    fun onMoveOutPrimaryAction(
        hasPro: Boolean,
        onOpenMoveOutProof: () -> Unit,
        onShowPaywall: (PaywallReason) -> Unit,
    ) {
        if (!hasPro) {
            onShowPaywall(PaywallReason.MoveOutReport)
            return
        }
        when (_uiState.value.moveOutReadiness) {
            MoveOutReportReadiness.NoProof -> onOpenMoveOutProof()
            MoveOutReportReadiness.ReadyToMake -> queueMoveOutReport()
            MoveOutReportReadiness.ReadyToShare -> shareMoveOutReport()
            MoveOutReportReadiness.Failed -> queueMoveOutReport()
            MoveOutReportReadiness.Processing -> Unit
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

    private fun queueMoveOutReport() {
        val property = propertyStore.currentProperty.value ?: return
        if (_moveOutActionInProgress.value) return
        if (MoveOutReportReadinessMapper.hasActiveMoveOutJob(_exports.value)) {
            _banner.value = "A move-out report is already building. Check status below." to false
            return
        }
        viewModelScope.launch {
            _moveOutActionInProgress.value = true
            _banner.value = null
            try {
                withContext(Dispatchers.IO) {
                    exportRepository.queueMoveOutReport(property.id)
                }
                _banner.value = "Move-out report queued. Building your PDF…" to false
                refreshExports()
            } catch (e: Exception) {
                _banner.value = exportRepository.userMessage(e) to true
            } finally {
                _moveOutActionInProgress.value = false
            }
        }
    }

    private fun shareMoveInReport() {
        val row = ReportReadinessMapper.firstReadyExport(_exports.value) ?: return
        shareExport(row)
    }

    private fun shareMoveOutReport() {
        val row = MoveOutReportReadinessMapper.firstReadyMoveOutExport(_exports.value) ?: return
        shareExport(row)
    }

    private fun shareDisputePacket() {
        val row = DisputePacketReadinessMapper.firstReadyDisputeExport(_exports.value) ?: return
        shareExport(row)
    }

    private fun queueDisputePacket() {
        val property = propertyStore.currentProperty.value ?: return
        if (_disputeActionInProgress.value) return
        if (DisputePacketReadinessMapper.hasActiveDisputeJob(_exports.value)) {
            _banner.value = "A dispute packet is already building. Check status below." to false
            return
        }
        viewModelScope.launch {
            _disputeActionInProgress.value = true
            _banner.value = null
            try {
                withContext(Dispatchers.IO) {
                    exportRepository.queueDisputePacket(property.id)
                }
                _banner.value = "Dispute packet queued. Building your PDF…" to false
                refreshExports()
            } catch (e: Exception) {
                _banner.value = exportRepository.userMessage(e) to true
            } finally {
                _disputeActionInProgress.value = false
            }
        }
    }

    fun shareExport(row: ExportRow) {
        if (_actionInProgress.value || _moveOutActionInProgress.value || _disputeActionInProgress.value) {
            return
        }
        viewModelScope.launch {
            when (row.type) {
                ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> _actionInProgress.value = true
                ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> _moveOutActionInProgress.value = true
                ReportReadinessMapper.DISPUTE_PACKET_TYPE -> _disputeActionInProgress.value = true
            }
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
                _moveOutActionInProgress.value = false
                _disputeActionInProgress.value = false
            }
        }
    }

    fun retryExport(row: ExportRow) {
        when (row.type) {
            ReportReadinessMapper.MOVE_IN_REPORT_TYPE -> queueMoveInReport()
            ReportReadinessMapper.MOVE_OUT_REPORT_TYPE -> queueMoveOutReport()
            ReportReadinessMapper.DISPUTE_PACKET_TYPE -> queueDisputePacket()
            else -> refreshExports()
        }
    }

    private fun buildUiState(
        property: PropertyRecord?,
        propertyLoading: Boolean,
        exports: List<ExportRow>,
        exportsLoading: Boolean,
        moveInBusy: Boolean,
        moveOutBusy: Boolean,
        disputeBusy: Boolean,
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
        val documented = RoomProofMetrics.moveInDocumentedCount(property)
        val total = property.rooms.size
        val photos = RoomProofMetrics.totalPhotoCount(property, ProofPhase.MoveIn)
        val moveOutPhotos = RoomProofMetrics.totalPhotoCount(property, ProofPhase.MoveOut)
        val moveOutDocumented = RoomProofMetrics.moveOutDocumentedCount(property)
        val moveOutReadiness = MoveOutReportReadinessMapper.resolve(moveOutPhotos, exports)
        val disputeReadiness = DisputePacketReadinessMapper.resolve(documented, exports)
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
            checklistItems = buildChecklist(documented, total, readiness, moveOutPhotos),
            exports = exports,
            moveInActionInProgress = moveInBusy,
            moveOutActionInProgress = moveOutBusy,
            disputeActionInProgress = disputeBusy,
            banner = banner?.first,
            bannerIsError = banner?.second == true,
            moveOutPhotos = moveOutPhotos,
            moveOutDocumentedRooms = moveOutDocumented,
            moveOutReadiness = moveOutReadiness,
            moveOutReportStatus = moveOutStatusLine(moveOutReadiness),
            disputeReadiness = disputeReadiness,
            disputePacketStatus = disputeStatusLine(disputeReadiness),
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
        moveOutPhotos: Int,
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
        val moveOutState = if (moveOutPhotos > 0) {
            ChecklistItemState.Complete
        } else {
            ChecklistItemState.Locked
        }
        return listOf(
            ReportChecklistItem(
                title = "Room photos",
                detail = if (total == 0) "Add rooms in your vault" else "$documented of $total rooms ready",
                state = roomsState,
            ),
            ReportChecklistItem(
                title = "Lease & docs",
                detail = "Add lease and deposit records in your vault",
                state = ChecklistItemState.Locked,
            ),
            ReportChecklistItem(
                title = "Damage tags",
                detail = if (documented == 0) {
                    "Tag issues while you photograph rooms"
                } else {
                    "Optional — tag scratches and stains as you go"
                },
                state = if (documented == 0) ChecklistItemState.Locked else ChecklistItemState.Incomplete,
            ),
            ReportChecklistItem(
                title = "Move-out proof",
                detail = if (moveOutPhotos > 0) "Move-out photos on file" else "Optional later — before you move out",
                state = moveOutState,
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

private fun disputeStatusLine(readiness: DisputePacketReadiness): String = when (readiness) {
    DisputePacketReadiness.NoProof -> "Add room proof first"
    DisputePacketReadiness.ReadyToMake -> "Packet can be built"
    DisputePacketReadiness.Processing -> "Building packet"
    DisputePacketReadiness.ReadyToShare -> "Packet ready"
    DisputePacketReadiness.Failed -> "Packet failed"
}

fun disputePrimaryCta(
    readiness: DisputePacketReadiness,
    loading: Boolean,
    busy: Boolean,
): Triple<String, Boolean, Boolean> {
    if (loading) return Triple("Checking dispute packet…", false, false)
    return when (readiness) {
        DisputePacketReadiness.NoProof -> Triple("Continue room proof", true, false)
        DisputePacketReadiness.ReadyToMake ->
            Triple(if (busy) "Building packet…" else "Build dispute packet", !busy, busy)
        DisputePacketReadiness.ReadyToShare ->
            Triple(if (busy) "Opening…" else "View / Share packet", !busy, busy)
        DisputePacketReadiness.Processing -> Triple("Building packet…", false, false)
        DisputePacketReadiness.Failed -> Triple(if (busy) "Retrying…" else "Retry packet", !busy, busy)
    }
}

private fun moveOutStatusLine(readiness: MoveOutReportReadiness): String = when (readiness) {
    MoveOutReportReadiness.NoProof -> "Capture move-out proof first"
    MoveOutReportReadiness.ReadyToMake -> "Move-out report can be made"
    MoveOutReportReadiness.Processing -> "Building move-out report"
    MoveOutReportReadiness.ReadyToShare -> "Move-out report ready"
    MoveOutReportReadiness.Failed -> "Move-out report failed"
}

private fun primaryCta(readiness: ReportReadiness, loading: Boolean, busy: Boolean): Triple<String, Boolean, Boolean> {
    if (loading) return Triple("Checking report…", false, false)
    return when (readiness) {
        ReportReadiness.NotReady, ReportReadiness.NoVault -> Triple("Continue room proof", true, false)
        ReportReadiness.ReadyToMake -> Triple(if (busy) "Making report…" else "Make report", !busy, busy)
        ReportReadiness.ReadyToShare -> Triple(if (busy) "Opening…" else "View / Share report", !busy, busy)
        ReportReadiness.Processing -> Triple("Building report…", false, false)
        ReportReadiness.Failed -> Triple(if (busy) "Retrying…" else "Retry report", !busy, busy)
    }
}

fun moveOutPrimaryCta(
    readiness: MoveOutReportReadiness,
    loading: Boolean,
    busy: Boolean,
): Triple<String, Boolean, Boolean> {
    if (loading) return Triple("Checking move-out report…", false, false)
    return when (readiness) {
        MoveOutReportReadiness.NoProof -> Triple("Open move-out proof", true, false)
        MoveOutReportReadiness.ReadyToMake ->
            Triple(if (busy) "Making move-out report…" else "Make move-out report", !busy, busy)
        MoveOutReportReadiness.ReadyToShare ->
            Triple(if (busy) "Opening…" else "View / Share report", !busy, busy)
        MoveOutReportReadiness.Processing -> Triple("Building move-out report…", false, false)
        MoveOutReportReadiness.Failed -> Triple(if (busy) "Retrying…" else "Retry report", !busy, busy)
    }
}

fun ReportsUiState.heroHeadline(): String = when (readiness) {
    ReportReadiness.NotReady, ReportReadiness.NoVault -> "Finish room proof first."
    ReportReadiness.ReadyToMake -> "You have enough proof to create a move-in report."
    ReportReadiness.ReadyToShare -> "Your move-in report is ready to share."
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
    if (totalRooms > 0) parts += "$documentedRooms of $totalRooms rooms"
    if (totalPhotos > 0) parts += if (totalPhotos == 1) "1 photo" else "$totalPhotos photos"
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}

fun ReportsUiState.primaryCta(): Triple<String, Boolean, Boolean> =
    primaryCta(readiness, propertyLoading || exportsLoading, moveInActionInProgress)

fun ReportsUiState.moveOutCta(hasPro: Boolean): Triple<String, Boolean, Boolean> {
    if (!hasPro) return Triple("Upgrade to Pro", true, false)
    return moveOutPrimaryCta(moveOutReadiness, propertyLoading || exportsLoading, moveOutActionInProgress)
}

fun ReportsUiState.disputeCta(hasPro: Boolean): Triple<String, Boolean, Boolean> {
    if (!hasPro) return Triple("Included with Pro", true, false)
    return disputePrimaryCta(disputeReadiness, propertyLoading || exportsLoading, disputeActionInProgress)
}
