package com.surensureshkumar.movemark.data.auth

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

enum class AuthState {
    Loading,
    SignedOut,
    SignedIn,
}

class AuthException(message: String) : Exception(message)

@Singleton
class SessionManager @Inject constructor(
    private val client: SupabaseClient,
    private val profileRepository: ProfileRepository,
    private val subscriptionRepository: SubscriptionRepository,
    @Suppress("UNUSED_PARAMETER") dataStore: DataStore<Preferences>,
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
            client.auth.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Authenticated -> applyUser(status.session.user?.id, status.session.user?.email)
                    is SessionStatus.NotAuthenticated -> clearUser()
                    is SessionStatus.Initializing -> _authState.value = AuthState.Loading
                    else -> Unit
                }
            }
        }
    }

    suspend fun signUp(email: String, password: String) {
        validateCredentials(email, password)
        client.auth.signUpWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        val user = client.auth.currentUserOrNull()
            ?: throw AuthException("Account created. Confirm your email, then sign in.")
        val uid = UUID.fromString(user.id)
        profileRepository.ensureProfileExists(uid, email.trim())
        applyUser(user.id, user.email ?: email.trim())
        subscriptionRepository.logIn(user.id)
    }

    suspend fun signIn(email: String, password: String) {
        validateCredentials(email, password)
        client.auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        val user = client.auth.currentUserOrNull()
            ?: throw AuthException("Sign in failed. Check your email and password.")
        val uid = UUID.fromString(user.id)
        profileRepository.ensureProfileExists(uid, user.email ?: email.trim())
        applyUser(user.id, user.email ?: email.trim())
        subscriptionRepository.logIn(user.id)
    }

    suspend fun resetPassword(email: String) {
        val trimmed = email.trim()
        if (trimmed.isEmpty()) throw AuthException("Enter your email.")
        client.auth.resetPasswordForEmail(trimmed)
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

    suspend fun signOut(onCleared: () -> Unit) {
        subscriptionRepository.logOut()
        client.auth.signOut()
        clearUser()
        onCleared()
    }

    suspend fun accessToken(): String? =
        client.auth.currentSessionOrNull()?.accessToken

    private fun validateCredentials(email: String, password: String) {
        if (email.trim().isEmpty()) throw AuthException("Enter your email.")
        if (password.length < 6) throw AuthException("Password must be at least 6 characters.")
    }

    private fun applyUser(id: String?, email: String?) {
        _userId.value = id?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        _userEmail.value = email
        _authState.value = if (id != null) AuthState.SignedIn else AuthState.SignedOut
        if (id != null) {
            scope.launch {
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
}
