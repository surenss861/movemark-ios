package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
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

    suspend fun addEvidence(
        roomId: UUID,
        title: String,
        notes: String,
        photos: List<ByteArray>,
        propertyId: UUID,
        userId: UUID,
    ): SaveEvidenceResult {
        if (photos.isEmpty()) throw IllegalArgumentException("Add at least one photo before saving.")
        val inspectionId = inspectionRepository.upsertInspection(propertyId, userId, "move_in")
        val itemId = inspectionRepository.insertInspectionItem(
            inspectionId = inspectionId,
            roomId = roomId,
            notes = "$title\n$notes",
            conditionRating = 4,
        )
        var saved = 0
        for (photo in photos) {
            val path = "${userId}/${propertyId}/move-in/${roomId}/${UUID.randomUUID()}.jpg"
            try {
                inspectionRepository.uploadPhoto(photo, path)
                inspectionRepository.insertEvidenceFile(propertyId, itemId, path)
                saved++
            } catch (_: Exception) {
                inspectionRepository.removeOrphanUpload(path)
            }
        }
        if (saved == 0) {
            inspectionRepository.deleteInspectionItem(itemId)
            throw IllegalStateException("Photos could not be uploaded. Check your connection and try again.")
        }
        applyOptimisticMoveIn(roomId, itemId, title, saved)
        val refreshed = refreshActive(userId)
        return SaveEvidenceResult(saved, photos.size, refreshed)
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
