package com.surensureshkumar.movemark.data.auth

import android.util.Log
import com.surensureshkumar.movemark.data.backend.BackendConfig
import com.surensureshkumar.movemark.data.backend.NeonAuthClient
import com.surensureshkumar.movemark.data.backend.NeonAuthException
import com.surensureshkumar.movemark.data.backend.NeonAuthUser
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.Lazy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

enum class AuthState {
    Loading,
    SignedOut,
    SignedIn,
}

class AuthException(message: String) : Exception(message)

/** The signed-in user, backed by Neon Auth ([NeonAuthClient] owns the session and its tokens). */
@Singleton
class SessionManager @Inject constructor(
    private val auth: NeonAuthClient,
    private val config: BackendConfig,
    private val profileRepository: ProfileRepository,
    private val subscriptionRepository: SubscriptionRepository,
    private val exportApi: ExportApiClient,
    private val fileUrls: StoredFileUrls,
    private val propertyStore: Lazy<PropertyStore>,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _authState = MutableStateFlow(AuthState.Loading)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    private val _userId = MutableStateFlow<UUID?>(null)
    val userId: StateFlow<UUID?> = _userId.asStateFlow()

    private val _userEmail = MutableStateFlow<String?>(null)
    val userEmail: StateFlow<String?> = _userEmail.asStateFlow()

    private val _userFullName = MutableStateFlow<String?>(null)
    val userFullName: StateFlow<String?> = _userFullName.asStateFlow()

    private val _hasFetchedProfile = MutableStateFlow(false)
    val hasFetchedProfile: StateFlow<Boolean> = _hasFetchedProfile.asStateFlow()

    init {
        scope.launch {
            // Identity comes from the session persisted on this device; no network needed to restore it.
            val user = withContext(Dispatchers.IO) { runCatching { auth.currentUser() }.getOrNull() }
            if (user != null) applyUser(user) else clearUser()
        }
        scope.launch {
            // Neon Auth rejected the stored session (expired, revoked, password reset elsewhere).
            auth.sessionExpired.collect {
                Log.i(TAG, "session expired; signing out locally")
                endLocalSession()
            }
        }
    }

    suspend fun signUp(email: String, password: String) {
        validateCredentials(email, password)
        val trimmed = email.trim()
        val user = auth.signUp(trimmed, password)
            ?: throw AuthException("Account created. Confirm your email, then sign in.")
        profileRepository.ensureProfileExists(UUID.fromString(user.id), user.email.ifBlank { trimmed })
        applyUser(user)
    }

    suspend fun signIn(email: String, password: String) {
        requireConfigured()
        val trimmed = email.trim()
        if (trimmed.isEmpty()) throw AuthException("Enter your email.")
        if (password.isEmpty()) throw AuthException("Enter your password.")
        val user = auth.signIn(trimmed, password)
        profileRepository.ensureProfileExists(UUID.fromString(user.id), user.email.ifBlank { trimmed })
        applyUser(user)
    }

    /** Asks Neon Auth to email a reset link. Handling the link itself is not part of this build. */
    suspend fun resetPassword(email: String) {
        requireConfigured()
        val trimmed = email.trim()
        if (trimmed.isEmpty()) throw AuthException("Enter your email.")
        auth.requestPasswordReset(trimmed)
    }

    suspend fun refreshProfile() {
        val uid = _userId.value ?: return
        _userFullName.value = profileRepository.fetchFullName(uid)
        _hasFetchedProfile.value = true
    }

    suspend fun updateProfileFullName(fullName: String) {
        val uid = _userId.value ?: throw AuthException("Sign in to update your profile.")
        profileRepository.updateFullName(uid, fullName)
        _userFullName.value = fullName.trim()
    }

    /** Hard reset: always clears local state, even if the server-side sign-out fails (e.g. offline). */
    suspend fun signOut(onCleared: suspend () -> Unit) {
        subscriptionRepository.logOut()
        auth.signOut()
        fileUrls.clear()
        clearUser()
        onCleared()
    }

    /**
     * Permanently deletes the account and its cloud data (`DELETE /api/account`), then signs out on this device.
     * The session is already gone server-side, so only local state is cleared.
     */
    suspend fun deleteAccount(onCleared: suspend () -> Unit) {
        exportApi.deleteAccount()
        subscriptionRepository.logOut()
        auth.endSessionLocally(notify = false)
        fileUrls.clear()
        clearUser()
        onCleared()
    }

    private suspend fun endLocalSession() {
        subscriptionRepository.logOut()
        fileUrls.clear()
        clearUser()
        propertyStore.get().clear()
    }

    private fun requireConfigured() {
        if (!config.isConfigured) throw AuthException(NeonAuthException.NotConfigured().message.orEmpty())
    }

    private fun validateCredentials(email: String, password: String) {
        requireConfigured()
        if (email.trim().isEmpty()) throw AuthException("Enter your email.")
        // Neon Auth's minimum; iOS checks the same before sending.
        if (password.length < 8) throw AuthException("Password must be at least 8 characters.")
    }

    private fun applyUser(user: NeonAuthUser) {
        val id = runCatching { UUID.fromString(user.id) }.getOrNull()
        _userId.value = id
        _userEmail.value = user.email
        _authState.value = if (id != null) AuthState.SignedIn else AuthState.SignedOut
        if (id != null) {
            scope.launch {
                // RevenueCat's app user id is the Neon Auth user id (lowercase uuid), as on iOS.
                subscriptionRepository.logIn(id.toString().lowercase())
                subscriptionRepository.refreshCustomerInfo()
                refreshProfile()
            }
        }
    }

    private fun clearUser() {
        _userId.value = null
        _userEmail.value = null
        _userFullName.value = null
        _hasFetchedProfile.value = false
        _authState.value = AuthState.SignedOut
    }

    private companion object {
        const val TAG = "SessionManager"
    }
}
