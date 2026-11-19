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
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class SocialSignInViewModel @Inject constructor(private val sessionManager: SessionManager) : ViewModel() {
    suspend fun signIn(context: Context, provider: SocialProvider) {
        SocialBrowserSession.lastMethod = provider.id
        sessionManager.signInWithSocial(provider.id) { url ->
            val returned = SocialBrowserSession.open(context, url)
            SocialBrowserReturn.verifier(
                verifier = returned.getQueryParameter("neon_auth_session_verifier"),
                error = returned.getQueryParameter("error"),
            )
        }
    }
}
