package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import android.util.Log
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.models.EvidenceRecord
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.PropertyRow
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

    private fun activeKey(userId: UUID) = stringPreferencesKey("active_property_${userId}")

    fun clear() {
        _currentProperty.value = null
        _properties.value = emptyList()
        _activePropertyId.value = null
        _errorMessage.value = null
        _hasCompletedInitialFetch.value = false
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
            _currentProperty.value = hydrator.hydrate(row)
            _errorMessage.value = null
        } catch (e: Exception) {
            _errorMessage.value = e.message ?: "Could not load your rentals."
            _currentProperty.value = null
        } finally {
            _isLoading.value = false
            _hasCompletedInitialFetch.value = true
        }
    }

    suspend fun createProperty(input: CreatePropertyInput, userId: UUID) {
        val created = propertyRepository.createProperty(input, userId)
        propertyRepository.insertDefaultRooms(UUID.fromString(created.id))
        _activePropertyId.value = UUID.fromString(created.id)
        dataStore.edit { it[activeKey(userId)] = created.id }
        fetchAll(userId)
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
    ): EvidenceUploadContext {
        val inspectionId = inspectionRepository.upsertInspection(propertyId, userId, "move_in")
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
        )
    }

    suspend fun uploadSingleEvidencePhoto(
        context: EvidenceUploadContext,
        photo: ByteArray,
    ): Boolean {
        val path =
            "${context.userId}/${context.propertyId}/move-in/${context.roomId}/${UUID.randomUUID()}.jpg"
        return try {
            inspectionRepository.uploadPhoto(photo, path)
            inspectionRepository.insertEvidenceFile(
                context.propertyId,
                context.inspectionItemId,
                path,
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
        applyOptimisticMoveIn(
            context.roomId,
            context.inspectionItemId,
            context.title,
            uploadedCount,
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
        val context = createEvidenceUploadContext(roomId, title, notes, propertyId, userId)
        var saved = 0
        for (photo in photos) {
            if (uploadSingleEvidencePhoto(context, photo)) saved++
        }
        return commitEvidenceUpload(context, saved, photos.size)
    }

    private fun applyOptimisticMoveIn(roomId: UUID, itemId: UUID, title: String, photoCount: Int) {
        val prop = _currentProperty.value ?: return
        val updatedRooms = prop.rooms.map { room ->
            if (room.id != roomId) return@map room
            val existing = room.evidence.firstOrNull()
            val evidence = if (existing != null) {
                room.evidence.map { e ->
                    if (e.id == existing.id) e.copy(photoCount = e.photoCount + photoCount) else e
                }
            } else {
                listOf(
                    EvidenceRecord(
                        id = itemId,
                        title = title,
                        notes = "",
                        photoCount = photoCount,
                    ),
                )
            }
            room.copy(evidence = evidence)
        }
        _currentProperty.value = prop.copy(rooms = updatedRooms)
    }
}
