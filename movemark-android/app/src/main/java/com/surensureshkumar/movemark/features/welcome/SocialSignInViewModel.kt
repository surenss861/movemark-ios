/**
 * @file Runs a social sign-in through the session manager; the root navigates once the session exists.
 * @domain onboarding-auth
 * @status wip
 * @see [[SocialSignIn.kt]]
 */
package com.surensureshkumar.movemark.features.welcome

import android.content.Context
import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.features.auth.social.SocialBrowserReturn
import com.surensureshkumar.movemark.features.auth.social.SocialBrowserSession
import com.surensureshkumar.movemark.features.auth.social.SocialProvider
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.features.auth.social.SocialSignInException
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * The attempt runs in [viewModelScope], so a recreated Activity (rotation, "Don't keep activities") finds it still
 * waiting for the browser's return instead of losing it.
 */
@HiltViewModel
class SocialSignInViewModel @Inject constructor(private val sessionManager: SessionManager) : ViewModel() {
    private val _busy = MutableStateFlow<SocialProvider?>(null)
    val busy: StateFlow<SocialProvider?> = _busy.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        // A browser return with no attempt behind it (the process was stopped while the browser was open).
        viewModelScope.launch {
            SocialBrowserSession.orphanedReturn.collect { orphaned ->
                if (orphaned && _busy.value == null) {
                    _error.value = SIGN_IN_INTERRUPTED
                    SocialBrowserSession.clearOrphanedReturn()
                }
            }
        }
    }

    fun start(activity: Context, provider: SocialProvider) {
        if (_busy.value != null) return
        _error.value = null
        _busy.value = provider
        viewModelScope.launch {
            try {
                signIn(activity, provider)
            } catch (e: SocialSignInException.Cancelled) {
                // Closed the browser; nothing to say.
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _error.value = e.message ?: SIGN_IN_INTERRUPTED
            } finally {
                _busy.value = null
            }
        }
    }

    suspend fun signIn(context: Context, provider: SocialProvider) {
        sessionManager.signInWithSocial(provider.id) { url ->
            val returned = SocialBrowserSession.open(context, url)
            SocialBrowserReturn.verifier(
                verifier = returned.getQueryParameter("neon_auth_session_verifier"),
                error = returned.getQueryParameter("error"),
            )
        }
        SocialBrowserSession.lastMethod = provider.id
    }

    companion object {
        const val SIGN_IN_INTERRUPTED = "Sign-in didn’t finish. Try again."
    }
}
