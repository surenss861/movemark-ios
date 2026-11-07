package com.surensureshkumar.movemark.features.dispute

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.export.ExportRepository
import com.surensureshkumar.movemark.data.export.ExportRow
import com.surensureshkumar.movemark.data.export.ReportFileDownloader
import com.surensureshkumar.movemark.data.property.DisputeDraft
import com.surensureshkumar.movemark.data.property.DisputeDraftStore
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.remote.ExportApiException
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import com.surensureshkumar.movemark.domain.DisputePacketModel
import com.surensureshkumar.movemark.features.reports.ReportLocalPdf
import com.surensureshkumar.movemark.features.reports.ReportPdfAction
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * The evidence packet builder, live (iOS `DisputePacketView`): reads the rental, its maintenance log and its
 * exports, keeps the renter's note on this phone, and generates / views / shares the packet through the same
 * export API as Reports.
 */
@HiltViewModel
class DisputePacketViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val propertyStore: PropertyStore,
    private val exportRepository: ExportRepository,
    private val subscriptionRepository: SubscriptionRepository,
    private val inspectionRepository: InspectionRepository,
    private val drafts: DisputeDraftStore,
) : ViewModel() {
    private val _exports = MutableStateFlow<List<ExportRow>>(emptyList())
    private val _selected = MutableStateFlow<Set<UUID>>(emptySet())
    private val _requesting = MutableStateFlow(false)

    val question = MutableStateFlow("")
    val amount = MutableStateFlow("")

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    /** The poll budget ran out with the packet still building ("Check again"). */
    private val _pollTimedOut = MutableStateFlow(false)
    val pollTimedOut: StateFlow<Boolean> = _pollTimedOut.asStateFlow()

    private val _downloading = MutableStateFlow(false)
    val downloading: StateFlow<Boolean> = _downloading.asStateFlow()

    private val _paywall = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val paywall: SharedFlow<Unit> = _paywall.asSharedFlow()

    private val _pdf = MutableSharedFlow<ReportLocalPdf>(extraBufferCapacity = 1)
    val pdf: SharedFlow<ReportLocalPdf> = _pdf.asSharedFlow()

    val model: StateFlow<DisputePacketModel?> = combine(
        propertyStore.currentProperty, propertyStore.maintenanceLog, _exports, _selected,
        combine(subscriptionRepository.hasPro, _requesting) { pro, req -> pro to req },
    ) { property, maintenance, exports, selected, (pro, requesting) ->
        property?.let { DisputePacketModel.make(it, maintenance, exports, selected, pro, requesting) }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private var propertyId: UUID? = null
    private var restored = false
    private var pollJob: Job? = null

    init {
        viewModelScope.launch {
            propertyStore.currentProperty.collect { property ->
                if (property == null || property.id == propertyId) return@collect
                propertyId = property.id
                restored = false
                val draft = drafts.load(property.id)
                if (draft == null) {
                    _selected.value = DisputePacketModel.defaultSelection(property.rooms)
                } else {
                    question.value = draft.question
                    amount.value = draft.amount
                    _selected.value = draft.rooms.mapNotNull { runCatching { UUID.fromString(it) }.getOrNull() }.toSet()
                }
                restored = true
                refreshAndPoll()
            }
        }
    }

    suspend fun signedPhotoUrl(path: String): String? = runCatching { inspectionRepository.signedUrl(path) }.getOrNull()

    fun setQuestion(value: String) { question.value = value; saveDraft() }
    fun setAmount(value: String) { amount.value = value; saveDraft() }

    fun toggleRoom(id: UUID) {
        _selected.value = if (id in _selected.value) _selected.value - id else _selected.value + id
        saveDraft()
    }

    private fun saveDraft() {
        val id = propertyId ?: return
        if (!restored) return
        val draft = DisputeDraft(question.value, amount.value, _selected.value.map { it.toString() })
        viewModelScope.launch { drafts.save(id, draft) }
    }

    private suspend fun loadExports() {
        val id = propertyId ?: return
        try {
            _exports.value = exportRepository.loadExports(id)
            _error.value = null
        } catch (e: Exception) {
            _error.value = "Couldn't load this rental's packets just now. Your evidence is unchanged."
        }
    }

    private val isGenerating: Boolean get() = _exports.value.any { it.type in DisputePacketModel.PACKET_TYPES && DisputePacketModel.isActive(it) }

    /** Reloads, then (re)starts the single status poll. */
    fun refreshAndPoll() {
        viewModelScope.launch {
            loadExports()
            startPolling()
        }
    }

    private fun startPolling() {
        pollJob?.cancel()
        _pollTimedOut.value = false
        pollJob = viewModelScope.launch {
            repeat(POLL_ATTEMPTS) {
                if (!isGenerating) return@launch
                delay(POLL_INTERVAL_MS)
                loadExports()
            }
            if (isGenerating) _pollTimedOut.value = true
        }
    }

    fun generate() {
        val id = propertyId ?: return
        if (_requesting.value) return
        if (!subscriptionRepository.hasPro.value) {
            _paywall.tryEmit(Unit)
            return
        }
        viewModelScope.launch {
            _requesting.value = true
            _error.value = null
            try {
                exportRepository.queueDisputePacket(id)
                loadExports()
            } catch (e: ExportApiException.PaymentRequired) {
                subscriptionRepository.refreshCustomerInfo()
                _paywall.tryEmit(Unit)
                return@launch
            } catch (e: ExportApiException.AlreadyActive) {
                loadExports()
            } catch (e: Exception) {
                _error.value = MMUserMessages.export(e).takeUnless { it.startsWith("Report couldn't complete") }
                    ?: "Couldn't start the evidence packet. Try again."
                return@launch
            } finally {
                _requesting.value = false
            }
            startPolling()
        }
    }

    /** View or share the newest packet; a second tap while it opens never starts another download. */
    fun open(share: Boolean) {
        val row = DisputePacketModel.latestPacket(_exports.value) ?: return
        if (_downloading.value) return
        viewModelScope.launch {
            _downloading.value = true
            _error.value = null
            try {
                val url = exportRepository.downloadUrl(row.id)
                val file = ReportFileDownloader.download(appContext, url, row.type, row.id.toString())
                _pdf.emit(ReportLocalPdf(file, "Evidence packet", if (share) ReportPdfAction.Share else ReportPdfAction.View))
            } catch (e: Exception) {
                _error.value = MMUserMessages.export(e)
            } finally {
                _downloading.value = false
            }
        }
    }

    override fun onCleared() {
        pollJob?.cancel()
        super.onCleared()
    }

    private companion object {
        const val POLL_ATTEMPTS = 48
        const val POLL_INTERVAL_MS = 2_500L
    }
}
