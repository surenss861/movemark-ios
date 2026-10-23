package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import android.util.Log
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.evidence.EvidenceSaveOutcome
import com.surensureshkumar.movemark.data.evidence.PendingEvidence
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.models.VaultSummary
import com.surensureshkumar.movemark.domain.ProofPhase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class SaveEvidenceResult(
    val savedCount: Int,
    val attemptedCount: Int,
    val hydrationRefreshed: Boolean,
    /** Photos that aren't confirmed saved; retry exactly these (never the saved ones). */
    val pending: List<PendingEvidence> = emptyList(),
) {
    val hadPartialFailure: Boolean get() = savedCount in 1 until attemptedCount
}

@Singleton
class PropertyStore @Inject constructor(
    private val propertyRepository: PropertyRepository,
    private val inspectionRepository: InspectionRepository,
    private val maintenanceRepository: MaintenanceRepository,
    private val hydrator: PropertyHydrator,
    private val fileUrls: StoredFileUrls,
    private val dataStore: DataStore<Preferences>,
) {
    private val _properties = MutableStateFlow<List<PropertyRow>>(emptyList())
    val properties: StateFlow<List<PropertyRow>> = _properties.asStateFlow()

    private val _currentProperty = MutableStateFlow<PropertyRecord?>(null)
    val currentProperty: StateFlow<PropertyRecord?> = _currentProperty.asStateFlow()

    private val _activePropertyId = MutableStateFlow<UUID?>(null)
    val activePropertyId: StateFlow<UUID?> = _activePropertyId.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _hasCompletedInitialFetch = MutableStateFlow(false)
    val hasCompletedInitialFetch: StateFlow<Boolean> = _hasCompletedInitialFetch.asStateFlow()

    private val _maintenanceLog = MutableStateFlow<List<MaintenanceRecord>>(emptyList())
    val maintenanceLog: StateFlow<List<MaintenanceRecord>> = _maintenanceLog.asStateFlow()

    private fun activeKey(userId: UUID) = stringPreferencesKey("active_property_${userId}")

    private var vaultSummaries: Pair<Long, Map<String, VaultSummary>>? = null

    private fun apply(hydrated: PropertyHydrator.Hydrated) {
        _currentProperty.value = hydrated.record
        _maintenanceLog.value = hydrated.maintenance
    }

    /** Call on sign-out to prevent stale data — including the offline snapshot cache — from showing for a different user. */
    suspend fun clear() {
        _currentProperty.value = null
        _properties.value = emptyList()
        _activePropertyId.value = null
        _errorMessage.value = null
        _hasCompletedInitialFetch.value = false
        _maintenanceLog.value = emptyList()
        vaultSummaries = null
        hydrator.clearCache()
    }

    suspend fun fetchAll(userId: UUID) {
        _errorMessage.value = null
        _isLoading.value = true
        try {
            val fetched = propertyRepository.fetchProperties(userId)
            _properties.value = fetched
            if (fetched.isEmpty()) {
                _currentProperty.value = null
                _activePropertyId.value = null
                return
            }
            val prefs = dataStore.data.first()
            val saved = prefs[activeKey(userId)]?.let { runCatching { UUID.fromString(it) }.getOrNull() }
            val targetId = saved?.takeIf { id -> fetched.any { it.id == id.toString() } }
                ?: UUID.fromString(fetched.first().id)
            _activePropertyId.value = targetId
            dataStore.edit { it[activeKey(userId)] = targetId.toString() }
            val row = fetched.first { it.id == targetId.toString() }

            // Instant local read so the UI isn't blank while the network hydrate below is in
            // flight -- see PropertySnapshotCache. No-op (returns null) if nothing's cached yet.
            hydrator.hydrateFromCache(row)?.let(::apply)

            try {
                apply(hydrator.hydrate(row))
                _errorMessage.value = null
            } catch (e: Exception) {
                Log.e("PropertyStore", "fetchAll hydrate failed", e)
                _errorMessage.value = MMUserMessages.loadRentals(e)
                // Keep showing the cached/previous property rather than blanking the screen over
                // a failed refresh -- only a listing failure (outer catch) clears it.
            }
        } catch (e: Exception) {
            Log.e("PropertyStore", "fetchAll failed", e)
            _errorMessage.value = MMUserMessages.loadRentals(e)
            _currentProperty.value = null
        } finally {
            _isLoading.value = false
            _hasCompletedInitialFetch.value = true
        }
    }

    suspend fun createProperty(input: CreatePropertyInput, userId: UUID) {
        val created = propertyRepository.createProperty(input, userId)
        propertyRepository.insertDefaultRooms(UUID.fromString(created.id))
        // Persist selection before fetchAll so it resolves the new property as active.
        dataStore.edit { it[activeKey(userId)] = created.id }
        fetchAll(userId)
    }

    class DuplicateRoomNameException : Exception("A room with that name already exists.")
    class InvalidRoomNameException : Exception("Enter a room name.")

    /** Adds a custom room to the active property and re-hydrates so it appears in Vault/Rooms. */
    suspend fun addRoom(propertyId: UUID, userId: UUID, name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) throw InvalidRoomNameException()

        val currentRooms = _currentProperty.value?.takeIf { it.id == propertyId }?.rooms
        val existingNames = currentRooms?.map { it.name } ?: propertyRepository.fetchRooms(propertyId).map { it.name }
        if (existingNames.any { it.trim().equals(trimmed, ignoreCase = true) }) {
            throw DuplicateRoomNameException()
        }

        val nextSortOrder = (propertyRepository.fetchRooms(propertyId).maxOfOrNull { it.sortOrder } ?: -1) + 1
        propertyRepository.insertRoom(propertyId, trimmed, nextSortOrder)
        refreshActive(userId)
    }

    suspend fun activateProperty(propertyId: UUID, userId: UUID) {
        val row = _properties.value.firstOrNull { it.id == propertyId.toString() } ?: return
        _activePropertyId.value = propertyId
        _isLoading.value = true
        _errorMessage.value = null
        try {
            dataStore.edit { it[activeKey(userId)] = propertyId.toString() }
            // Instant local read first (see fetchAll's comment), then refresh from network.
            hydrator.hydrateFromCache(row)?.let(::apply)
            apply(hydrator.hydrate(row))
        } catch (e: Exception) {
            Log.e("PropertyStore", "activateProperty failed", e)
            _errorMessage.value = MMUserMessages.activateRental(e)
            // Keep whatever's currently shown (cached snapshot or the previously-active property)
            // instead of blanking the screen over a failed refresh.
        } finally {
            _isLoading.value = false
        }
    }

    suspend fun refreshActive(userId: UUID): Boolean {
        val activeId = _activePropertyId.value ?: return run {
            fetchAll(userId)
            _errorMessage.value == null
        }
        val row = _properties.value.firstOrNull { it.id == activeId.toString() } ?: return false
        return try {
            apply(hydrator.hydrate(row))
            vaultSummaries = null
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Rooms, documented rooms and newest evidence for every rental, from one aggregate call
     * (`get_vault_summaries`), never a snapshot per rental. Cached for 30 s; a failed refresh keeps the last result.
     */
    suspend fun vaultSummaries(): Map<String, VaultSummary> {
        val now = System.currentTimeMillis()
        vaultSummaries?.takeIf { now - it.first < VAULT_SUMMARY_TTL_MS }?.let { return it.second }
        return try {
            propertyRepository.fetchVaultSummaries()
                .associateBy { it.propertyId.lowercase() }
                .also { vaultSummaries = now to it }
        } catch (e: Exception) {
            Log.e("PropertyStore", "vault summaries failed", e)
            vaultSummaries?.second.orEmpty()
        }
    }

    /**
     * Appends the next page of older entries for a room and stage, moving them out of the room's unloaded
     * remainder so totals stay exactly what the server counted. Returns whether more remain.
     */
    suspend fun loadOlderEntries(roomId: UUID, phase: ProofPhase, pageSize: Int = 30): Boolean {
        val moveOut = phase == ProofPhase.MoveOut
        val room = _currentProperty.value?.rooms?.firstOrNull { it.id == roomId } ?: return false
        if (!room.hasOlderEntries(moveOut)) return false
        val cursor = EvidenceHistory.olderEntriesCursor(room.evidence(moveOut))
        val page = propertyRepository.fetchRoomEntriesPage(roomId, phase.key, cursor?.createdAt, cursor?.id, pageSize)
        page.entries.evidenceFiles.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) }
        val defaultTitle = if (moveOut) "Move-out capture" else "Move-in capture"
        updateRoom(roomId) { EvidenceHistory.applyOlderEntries(it, moveOut, page, defaultTitle) }
        return page.hasMore
    }

    /** Loads every remaining photo of one entry (capture order), page by page. */
    suspend fun loadAllPhotos(entryId: UUID, roomId: UUID, phase: ProofPhase, pageSize: Int = 200) {
        val moveOut = phase == ProofPhase.MoveOut
        fun entry(): EvidenceRecord? = _currentProperty.value?.rooms?.firstOrNull { it.id == roomId }
            ?.evidence(moveOut)?.firstOrNull { it.id == entryId }
        var loaded = entry() ?: return
        var hasMore = loaded.hasUnloadedPhotos
        while (hasMore && loaded.hasUnloadedPhotos) {
            val cursor = EvidenceHistory.photosCursor(loaded.photos)
            val page = propertyRepository.fetchEntryPhotosPage(entryId, cursor?.createdAt, cursor?.id, pageSize)
            page.evidenceFiles.forEach { fileUrls.remember(it.id, it.filePath, it.thumbnailPath) }
            loaded = EvidenceHistory.appendPhotos(loaded, page.evidenceFiles)
            hasMore = page.hasMore && page.evidenceFiles.isNotEmpty()
        }
        updateRoom(roomId) { room ->
            val replace = { list: List<EvidenceRecord> -> list.map { if (it.id == entryId) loaded else it } }
            if (moveOut) room.copy(moveOutEvidence = replace(room.moveOutEvidence))
            else room.copy(moveInEvidence = replace(room.moveInEvidence))
        }
    }

    private fun updateRoom(roomId: UUID, transform: (RoomRecord) -> RoomRecord) {
        val prop = _currentProperty.value ?: return
        _currentProperty.value = prop.copy(rooms = prop.rooms.map { if (it.id == roomId) transform(it) else it })
    }

    suspend fun refreshMaintenance(propertyId: UUID): Boolean {
        return try {
            val rows = maintenanceRepository.fetchIssues(propertyId)
            val photoCounts = inspectionRepository.fetchMaintenancePhotoCounts(propertyId)
            _maintenanceLog.value = rows.map { row ->
                val id = UUID.fromString(row.id)
                MaintenanceRecord(
                    id = id,
                    title = row.title,
                    category = row.category ?: "General",
                    details = row.description ?: "",
                    status = row.status,
                    landlordResponse = row.landlordResponse,
                    photoCount = photoCounts[id] ?: 0,
                    createdAt = row.createdAt,
                )
            }
            true
        } catch (e: Exception) {
            Log.e("PropertyStore", "refreshMaintenance failed", e)
            false
        }
    }

    private companion object {
        /** "Good" — iOS `RoomRecord.ConditionRating.good`, the capture form's default. */
        const val DEFAULT_CONDITION_RATING = 4
        const val UPLOAD_TAG = "MoveMarkUpload"
        const val VAULT_SUMMARY_TTL_MS = 30_000L
        const val UPLOAD_FAILURE_MESSAGE =
            "Photos couldn't upload. Check your connection and try again."
    }

    suspend fun createEvidenceUploadContext(
        roomId: UUID,
        title: String,
        notes: String,
        propertyId: UUID,
        userId: UUID,
        proofPhase: ProofPhase = ProofPhase.MoveIn,
        conditionRating: Int = DEFAULT_CONDITION_RATING,
        issueTags: List<String> = emptyList(),
    ): EvidenceUploadContext {
        val inspectionId = inspectionRepository.upsertInspection(propertyId, userId, proofPhase.key)
        val itemId = inspectionRepository.insertInspectionItem(
            inspectionId = inspectionId,
            roomId = roomId,
            notes = "$title\n$notes",
            conditionRating = conditionRating,
        )
        return EvidenceUploadContext(
            inspectionItemId = itemId,
            roomId = roomId,
            title = title,
            propertyId = propertyId,
            userId = userId,
            proofPhase = proofPhase,
            issueTags = issueTags,
        )
    }

    /**
     * Saves one photo of a new entry: upload (source, derivative, thumbnail, finalize) then its row, under the
     * photo's stable row id. A pending outcome carries what the retry needs; a saved photo is never re-sent.
     */
    suspend fun saveEvidencePhoto(context: EvidenceUploadContext, item: PendingEvidence): EvidenceSaveOutcome {
        val outcome = inspectionRepository.evidenceSaver(
            inspectionItemId = context.inspectionItemId,
            roomId = context.roomId,
            propertyId = context.propertyId,
            isMoveOut = context.proofPhase == ProofPhase.MoveOut,
        ).saveOne(item)
        if (outcome is EvidenceSaveOutcome.Pending) {
            Log.e(UPLOAD_TAG, "Photo not saved room=${context.roomId} row=${item.rowId}", outcome.error)
        }
        return outcome
    }

    suspend fun commitEvidenceUpload(
        context: EvidenceUploadContext,
        uploadedCount: Int,
        attemptedCount: Int,
    ): SaveEvidenceResult {
        if (uploadedCount <= 0) {
            runCatching {
                inspectionRepository.deleteInspectionItem(context.inspectionItemId)
            }.onFailure {
                Log.e(UPLOAD_TAG, "Failed to roll back empty evidence item", it)
            }
            throw IllegalStateException(UPLOAD_FAILURE_MESSAGE)
        }
        // Tags are optional metadata: a failure here must not turn a saved entry into "save failed".
        if (context.issueTags.isNotEmpty()) {
            runCatching { inspectionRepository.insertItemTags(context.inspectionItemId, context.issueTags) }
                .onFailure { Log.e(UPLOAD_TAG, "insertItemTags failed after save (evidence stored)", it) }
        }
        applyOptimisticEvidence(
            context.roomId,
            context.inspectionItemId,
            context.title,
            uploadedCount,
            context.proofPhase,
        )
        val refreshed = refreshActive(context.userId)
        return SaveEvidenceResult(uploadedCount, attemptedCount, refreshed)
    }

    /** Edit a saved entry. Mirrors iOS `updateEvidence`: item first, then replace its tag links. */
    suspend fun updateEvidence(
        entryId: UUID,
        title: String,
        notes: String,
        issueTags: List<String>,
        conditionRating: Int,
        userId: UUID,
    ): Boolean {
        inspectionRepository.updateInspectionItem(entryId, "$title\n$notes", conditionRating)
        inspectionRepository.deleteItemTags(entryId)
        if (issueTags.isNotEmpty()) inspectionRepository.insertItemTags(entryId, issueTags)
        return refreshActive(userId)
    }

    /** Delete a saved entry with its photos and tags. Mirrors iOS `deleteEvidence`. */
    suspend fun deleteEvidence(entryId: UUID, userId: UUID): Boolean {
        inspectionRepository.deleteInspectionItem(entryId)
        return refreshActive(userId)
    }

    /**
     * Add photos to an existing entry. Unlike a new save, a failed batch never deletes the
     * entry — it already holds the user's earlier photos.
     */
    suspend fun appendPhotosToEvidence(
        entryId: UUID,
        roomId: UUID,
        proofPhase: ProofPhase,
        photos: List<PendingEvidence>,
        propertyId: UUID,
        userId: UUID,
    ): SaveEvidenceResult {
        val result = inspectionRepository.evidenceSaver(
            inspectionItemId = entryId,
            roomId = roomId,
            propertyId = propertyId,
            isMoveOut = proofPhase == ProofPhase.MoveOut,
        ).save(photos)
        if (result.saved.isEmpty()) throw IllegalStateException(UPLOAD_FAILURE_MESSAGE)
        val refreshed = refreshActive(userId)
        return SaveEvidenceResult(result.saved.size, photos.size, refreshed, result.pending)
    }

    suspend fun abandonEvidenceUpload(context: EvidenceUploadContext) {
        runCatching {
            inspectionRepository.deleteInspectionItem(context.inspectionItemId)
        }.onFailure {
            Log.e(UPLOAD_TAG, "Failed to abandon evidence upload", it)
        }
    }

    private fun applyOptimisticEvidence(
        roomId: UUID,
        itemId: UUID,
        title: String,
        photoCount: Int,
        phase: ProofPhase,
    ) {
        val prop = _currentProperty.value ?: return
        val updatedRooms = prop.rooms.map { room ->
            if (room.id != roomId) return@map room
            val existingList = when (phase) {
                ProofPhase.MoveIn -> room.moveInEvidence
                ProofPhase.MoveOut -> room.moveOutEvidence
            }
            // Each save creates a brand-new inspection_item row (see createEvidenceUploadContext),
            // so itemId is never an existing record's id except on a retry of the same context.
            // Append a new entry rather than merging counts into an unrelated pre-existing one.
            val updatedEvidence = if (existingList.any { it.id == itemId }) {
                existingList.map { e ->
                    if (e.id == itemId) e.copy(photoCount = e.photoCount + photoCount) else e
                }
            } else {
                existingList + EvidenceRecord(
                    id = itemId,
                    title = title,
                    notes = "",
                    photoCount = photoCount,
                )
            }
            when (phase) {
                ProofPhase.MoveIn -> room.copy(moveInEvidence = updatedEvidence)
                ProofPhase.MoveOut -> room.copy(moveOutEvidence = updatedEvidence)
            }
        }
        _currentProperty.value = prop.copy(rooms = updatedRooms)
    }
}
