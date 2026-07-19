package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import android.util.Log
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.core.util.thumbnailPathFor
import com.surensureshkumar.movemark.core.util.toThumbnailJpeg
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
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
) {
    val hadPartialFailure: Boolean get() = savedCount in 1 until attemptedCount
}

@Singleton
class PropertyStore @Inject constructor(
    private val propertyRepository: PropertyRepository,
    private val inspectionRepository: InspectionRepository,
    private val maintenanceRepository: MaintenanceRepository,
    private val hydrator: PropertyHydrator,
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

    /** Call on sign-out to prevent stale data — including the offline snapshot cache — from showing for a different user. */
    suspend fun clear() {
        _currentProperty.value = null
        _properties.value = emptyList()
        _activePropertyId.value = null
        _errorMessage.value = null
        _hasCompletedInitialFetch.value = false
        _maintenanceLog.value = emptyList()
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
            hydrator.hydrateFromCache(row)?.let { cached -> _currentProperty.value = cached }

            try {
                _currentProperty.value = hydrator.hydrate(row)
                _errorMessage.value = null
            } catch (e: Exception) {
                Log.e("PropertyStore", "fetchAll hydrate failed", e)
                _errorMessage.value = MMUserMessages.loadRentals(e)
                // Keep showing the cached/previous property rather than blanking the screen over
                // a failed refresh -- only a listing failure (outer catch) clears it.
            }
            refreshMaintenance(targetId)
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
            hydrator.hydrateFromCache(row)?.let { cached -> _currentProperty.value = cached }
            _currentProperty.value = hydrator.hydrate(row)
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
            _currentProperty.value = hydrator.hydrate(row)
            true
        } catch (_: Exception) {
            false
        }
    }

    suspend fun refreshMaintenance(propertyId: UUID): Boolean {
        return try {
            val rows = maintenanceRepository.fetchIssues(propertyId)
            val issueIds = rows.map { UUID.fromString(it.id) }
            val photoCounts = inspectionRepository.fetchEvidenceFileCountsByMaintenanceIssue(issueIds)
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
        const val UPLOAD_TAG = "MoveMarkUpload"
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
    ): EvidenceUploadContext {
        val inspectionId = inspectionRepository.upsertInspection(propertyId, userId, proofPhase.key)
        val itemId = inspectionRepository.insertInspectionItem(
            inspectionId = inspectionId,
            roomId = roomId,
            notes = "$title\n$notes",
            conditionRating = 4,
        )
        return EvidenceUploadContext(
            inspectionItemId = itemId,
            roomId = roomId,
            title = title,
            propertyId = propertyId,
            userId = userId,
            proofPhase = proofPhase,
        )
    }

    suspend fun uploadSingleEvidencePhoto(
        context: EvidenceUploadContext,
        photo: ByteArray,
    ): Boolean {
        val path =
            "${context.userId}/${context.propertyId}/${context.proofPhase.storageFolder}/${context.roomId}/${UUID.randomUUID()}.jpg"
        return try {
            inspectionRepository.uploadPhoto(photo, path)
            // Thumbnail is a best-effort enhancement (grid loading only) -- its failure shouldn't
            // fail the evidence save, which is why it's uploaded after the full-size photo lands.
            val thumbPath = thumbnailPathFor(path)
            val thumbBytes = photo.toThumbnailJpeg()
            val thumbUploaded = thumbBytes != null && inspectionRepository.uploadThumbnail(thumbBytes, thumbPath)
            inspectionRepository.insertEvidenceFile(
                context.propertyId,
                context.inspectionItemId,
                path,
                thumbnailPath = if (thumbUploaded) thumbPath else null,
            )
            true
        } catch (e: Exception) {
            Log.e(UPLOAD_TAG, "Photo upload failed room=${context.roomId} path=$path", e)
            inspectionRepository.removeOrphanUpload(path)
            false
        }
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

    suspend fun abandonEvidenceUpload(context: EvidenceUploadContext) {
        runCatching {
            inspectionRepository.deleteInspectionItem(context.inspectionItemId)
        }.onFailure {
            Log.e(UPLOAD_TAG, "Failed to abandon evidence upload", it)
        }
    }

    /** @deprecated Prefer [createEvidenceUploadContext] + per-photo upload for progress/retry. */
    suspend fun addEvidence(
        roomId: UUID,
        title: String,
        notes: String,
        photos: List<ByteArray>,
        propertyId: UUID,
        userId: UUID,
    ): SaveEvidenceResult {
        if (photos.isEmpty()) throw IllegalArgumentException("Add at least one photo before saving.")
        val context = createEvidenceUploadContext(roomId, title, notes, propertyId, userId, ProofPhase.MoveIn)
        var saved = 0
        for (photo in photos) {
            if (uploadSingleEvidencePhoto(context, photo)) saved++
        }
        return commitEvidenceUpload(context, saved, photos.size)
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
