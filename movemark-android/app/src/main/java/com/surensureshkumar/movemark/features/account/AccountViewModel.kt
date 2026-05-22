package com.surensureshkumar.movemark.features.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import android.util.Log
import com.surensureshkumar.movemark.BuildConfig
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.data.subscription.SubscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AccountNotice(
    val message: String,
    val isError: Boolean = false,
)

@HiltViewModel
class AccountViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
    private val subscriptionRepository: SubscriptionRepository,
) : ViewModel() {
    companion object {
        const val PRIVACY_URL =
            "https://silver-peripheral-2ef.notion.site/MoveMark-Privacy-Policy-32f38275720980658acbe9aafa4e331b"
        const val TERMS_URL =
            "https://silver-peripheral-2ef.notion.site/MoveMark-Terms-of-Service-32f382757209804aa569e43311b492b1"
        const val SUPPORT_URL =
            "https://silver-peripheral-2ef.notion.site/Contact-Support-32f38275720980248f36d19e1ea533d8"
        const val ACCOUNT_DELETION_URL =
            "https://silver-peripheral-2ef.notion.site/MoveMark-Account-Data-Deletion-32f3827572098020aa45d0bacc3d13a5"
        const val SUPPORT_EMAIL = "support@movemark.app"
    }

    val isMockMode: Boolean get() = subscriptionRepository.isMockMode
    val email: StateFlow<String?> = sessionManager.userEmail
    val fullName: StateFlow<String?> = sessionManager.userFullName
    val hasPro: StateFlow<Boolean> = subscriptionRepository.hasPro
    val restoreMessage: StateFlow<String?> = subscriptionRepository.restoreMessage
    val purchasing: StateFlow<Boolean> = subscriptionRepository.purchasing

    private val _resetInProgress = MutableStateFlow(false)
    val resetInProgress: StateFlow<Boolean> = _resetInProgress.asStateFlow()

    private val _profileSaving = MutableStateFlow(false)
    val profileSaving: StateFlow<Boolean> = _profileSaving.asStateFlow()

    private val _notice = MutableStateFlow<AccountNotice?>(null)
    val notice: StateFlow<AccountNotice?> = _notice.asStateFlow()

    val appVersion: String = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    fun refresh() {
        viewModelScope.launch {
            subscriptionRepository.refreshCustomerInfo()
            sessionManager.refreshProfile()
        }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            _notice.value = null
            subscriptionRepository.restorePurchases()
        }
    }

    fun resetTestSubscription() {
        viewModelScope.launch {
            subscriptionRepository.resetMockSubscription()
            _notice.value = AccountNotice("Test subscription reset.")
        }
    }

    fun sendPasswordReset() {
        val email = sessionManager.userEmail.value?.trim().orEmpty()
        if (email.isEmpty()) {
            _notice.value = AccountNotice("No email on file.", isError = true)
            return
        }
        viewModelScope.launch {
            _resetInProgress.value = true
            _notice.value = null
            try {
                sessionManager.resetPassword(email)
                _notice.value = AccountNotice("Check your email for a link to reset your password.")
            } catch (e: AuthException) {
                _notice.value = AccountNotice(MMUserMessages.passwordReset(e), isError = true)
            } catch (e: Exception) {
                Log.e("AccountViewModel", "resetPassword failed", e)
                _notice.value = AccountNotice(MMUserMessages.passwordReset(e), isError = true)
            } finally {
                _resetInProgress.value = false
            }
        }
    }

    fun updateFullName(name: String) {
        viewModelScope.launch {
            _profileSaving.value = true
            _notice.value = null
            try {
                sessionManager.updateProfileFullName(name)
                _notice.value = AccountNotice("Name updated.")
            } catch (e: AuthException) {
                _notice.value = AccountNotice(MMUserMessages.profile(e), isError = true)
            } catch (e: Exception) {
                Log.e("AccountViewModel", "updateFullName failed", e)
                _notice.value = AccountNotice(MMUserMessages.profile(e), isError = true)
            } finally {
                _profileSaving.value = false
            }
        }
    }

    fun signOut(onDone: () -> Unit) {
        viewModelScope.launch {
            sessionManager.signOut { propertyStore.clear() }
            onDone()
        }
    }

    fun dismissNotice() {
        _notice.value = null
    }
}
