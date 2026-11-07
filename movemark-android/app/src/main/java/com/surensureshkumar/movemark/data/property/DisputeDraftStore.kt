package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/** What the renter typed in the packet builder; kept on this phone only (iOS `mm.disputeDraft.<propertyId>`). */
@Serializable
data class DisputeDraft(val question: String = "", val amount: String = "", val rooms: List<String> = emptyList())

@Singleton
class DisputeDraftStore @Inject constructor(private val dataStore: DataStore<Preferences>) {
    private val json = Json { ignoreUnknownKeys = true }

    private fun key(propertyId: UUID) = stringPreferencesKey("dispute_draft_${propertyId.toString().lowercase()}")

    /** Null on first open (the builder then starts from the rooms that changed). */
    suspend fun load(propertyId: UUID): DisputeDraft? =
        dataStore.data.first()[key(propertyId)]?.let { runCatching { json.decodeFromString(DisputeDraft.serializer(), it) }.getOrNull() }

    suspend fun save(propertyId: UUID, draft: DisputeDraft) {
        dataStore.edit { it[key(propertyId)] = json.encodeToString(DisputeDraft.serializer(), draft) }
    }
}
