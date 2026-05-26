package com.surensureshkumar.movemark.data.firstrun

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.firstRunDataStore by preferencesDataStore("movemark_first_run")

@Singleton
class FirstRunProofPreferences @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private fun key(userId: String) = booleanPreferencesKey("first_run_complete_$userId")

    suspend fun isComplete(userId: String): Boolean =
        context.firstRunDataStore.data.map { it[key(userId)] == true }.first()

    suspend fun markComplete(userId: String) {
        context.firstRunDataStore.edit { it[key(userId)] = true }
    }
}
