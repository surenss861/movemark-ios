package com.surensureshkumar.movemark.data.auth

import android.content.Context
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * After a password reset on this device, the first session signs every other device out (iOS
 * `PendingSessionRevocation`). Managed Neon Auth keeps other sessions on reset, so the mark lasts an hour and the
 * revocation is retried at launch while the mark stands.
 */
@Singleton
class PendingSessionRevocation internal constructor(
    private val store: Store,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    @Inject constructor(@ApplicationContext context: Context) : this(PrefsStore(context))

    interface Store {
        var untilMillis: Long
    }

    private class PrefsStore(context: Context) : Store {
        private val prefs = context.getSharedPreferences("movemark_auth", Context.MODE_PRIVATE)
        override var untilMillis: Long
            get() = prefs.getLong(KEY, 0L)
            set(value) { prefs.edit().apply { if (value > 0) putLong(KEY, value) else remove(KEY) }.apply() }
    }

    enum class Outcome { NothingPending, Revoked, SessionGone, WillRetry }

    fun markPasswordReset() { store.untilMillis = nowMillis() + WINDOW_MILLIS }

    fun isPending(): Boolean {
        val until = store.untilMillis
        if (until <= 0) return false
        if (nowMillis() < until) return true
        store.untilMillis = 0
        return false
    }

    /** Runs [revoke] when a reset is pending; clears the mark unless it should be retried. */
    suspend fun performIfPending(revoke: suspend () -> Unit): Outcome {
        if (!isPending()) return Outcome.NothingPending
        return try {
            revoke()
            store.untilMillis = 0
            Outcome.Revoked
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: NeonAuthException.SessionExpired) {
            store.untilMillis = 0
            Outcome.SessionGone
        } catch (e: Exception) {
            Outcome.WillRetry
        }
    }

    companion object {
        const val WINDOW_MILLIS = 60L * 60L * 1000L
        private const val KEY = "pending_session_revocation_until"
    }
}
