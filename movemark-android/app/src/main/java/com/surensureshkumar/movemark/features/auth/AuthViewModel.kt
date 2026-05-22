package com.surensureshkumar.movemark.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.AuthException
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class AuthMode { SignIn, SignUp }

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
) : ViewModel() {
    private val _mode = MutableStateFlow(AuthMode.SignIn)
    val mode: StateFlow<AuthMode> = _mode.asStateFlow()

    fun setMode(value: AuthMode) {
        _mode.value = value
    }

    private val _email = MutableStateFlow("")
    val email: StateFlow<String> = _email.asStateFlow()

    private val _password = MutableStateFlow("")
    val password: StateFlow<String> = _password.asStateFlow()

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    fun setEmail(v: String) { _email.value = v }
    fun setPassword(v: String) { _password.value = v }

    fun submit() {
        viewModelScope.launch {
            _loading.value = true
            _message.value = null
            try {
                when (_mode.value) {
                    AuthMode.SignUp -> sessionManager.signUp(_email.value, _password.value)
                    AuthMode.SignIn -> sessionManager.signIn(_email.value, _password.value)
                }
                sessionManager.userId.value?.let { propertyStore.fetchAll(it) }
            } catch (e: AuthException) {
                _message.value = MMUserMessages.auth(e)
            } catch (e: Exception) {
                _message.value = MMUserMessages.auth(e)
            } finally {
                _loading.value = false
            }
        }
    }

    fun resetPassword() {
        viewModelScope.launch {
            try {
                sessionManager.resetPassword(_email.value)
                _message.value = "Check your email for a reset link."
            } catch (e: Exception) {
                _message.value = MMUserMessages.passwordReset(e)
            }
        }
    }
}
