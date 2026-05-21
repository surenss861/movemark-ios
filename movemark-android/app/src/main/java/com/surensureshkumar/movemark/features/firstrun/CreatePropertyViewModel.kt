package com.surensureshkumar.movemark.features.firstrun

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CreatePropertyViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
) : ViewModel() {
    private val _title = MutableStateFlow("")
    val title: StateFlow<String> = _title.asStateFlow()
    private val _address = MutableStateFlow("")
    val address: StateFlow<String> = _address.asStateFlow()
    private val _city = MutableStateFlow("")
    val city: StateFlow<String> = _city.asStateFlow()
    private val _region = MutableStateFlow("")
    val region: StateFlow<String> = _region.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun setTitle(v: String) { _title.value = v }
    fun setAddress(v: String) { _address.value = v }
    fun setCity(v: String) { _city.value = v }
    fun setRegion(v: String) { _region.value = v }

    fun create(onDone: () -> Unit) {
        val userId = sessionManager.userId.value ?: return
        if (_address.value.trim().isEmpty()) {
            _error.value = "Enter a street address."
            return
        }
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            try {
                propertyStore.createProperty(
                    CreatePropertyInput(
                        title = _title.value,
                        addressLine1 = _address.value,
                        city = _city.value,
                        region = _region.value,
                        postalCode = "",
                    ),
                    userId,
                )
                onDone()
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _loading.value = false
            }
        }
    }
}
