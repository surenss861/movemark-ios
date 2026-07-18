package com.surensureshkumar.movemark.features.proof.camera

import android.net.Uri
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.first
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Hands captured photo URIs from [CameraCaptureScreen] back to the room proof screen that
 * launched it. Persisted in DataStore rather than kept only in memory: the photos are already
 * durable files on disk by the time "Done" is tapped, but an in-memory-only hand-off would still
 * lose track of them (leaving them orphaned) if the process dies between delivery and the room
 * screen resuming to consume them.
 */
@Singleton
class CameraCaptureResultHolder @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    private fun key(roomId: UUID) = stringPreferencesKey("camera_pending_$roomId")

    suspend fun deliver(roomId: UUID, uris: List<Uri>) {
        dataStore.edit { prefs ->
            prefs[key(roomId)] = uris.joinToString("\n") { it.toString() }
        }
    }

    suspend fun consume(roomId: UUID): List<Uri>? {
        val raw = dataStore.data.first()[key(roomId)] ?: return null
        dataStore.edit { it.remove(key(roomId)) }
        val uris = raw.split("\n").filter { it.isNotBlank() }.map(Uri::parse)
        return uris.takeIf { it.isNotEmpty() }
    }
}
