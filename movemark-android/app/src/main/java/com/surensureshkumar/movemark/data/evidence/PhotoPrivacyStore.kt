/**
 * @file The account's photo rule, kept per user id on the device so an offline launch still knows it. The server's
 *       `age_category` (from `get_legal_status`) is the source; this only remembers the last answer.
 * @domain evidence
 * @status stable
 * @see [[TeenPhotoPrivacy.kt]]
 */
package com.surensureshkumar.movemark.data.evidence

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first

private val Context.photoPrivacyDataStore by preferencesDataStore("movemark_photo_privacy")

@Singleton
class PhotoPrivacyStore @Inject constructor(@ApplicationContext private val context: Context) {
    private fun key(userId: String) = stringPreferencesKey("photo_privacy_${userId.lowercase()}")

    /** At sign-in, before the status call answers (or when it can't): this account's last known rule. */
    suspend fun restore(userId: String) {
        val saved = runCatching { context.photoPrivacyDataStore.data.first()[key(userId)] }.getOrNull()
        PhotoPrivacyPolicy.current = PhotoPrivacy.entries.firstOrNull { it.name == saved } ?: PhotoPrivacy.Standard
    }

    /** From the server's `age_category`. Null (nothing declared yet) keeps whatever this account last had. */
    suspend fun apply(serverCategory: String?, userId: String) {
        val next = PhotoPrivacyPolicy.fromServerCategory(serverCategory) ?: return restore(userId)
        PhotoPrivacyPolicy.current = next
        runCatching { context.photoPrivacyDataStore.edit { it[key(userId)] = next.name } }
    }

    /** Signed out: the next account starts from its own rule. */
    fun reset() {
        PhotoPrivacyPolicy.current = PhotoPrivacy.Standard
    }
}
