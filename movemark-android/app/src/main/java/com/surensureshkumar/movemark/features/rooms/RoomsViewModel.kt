package com.surensureshkumar.movemark.features.rooms

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class RoomsViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
) : ViewModel() {
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val loading: StateFlow<Boolean> = propertyStore.isLoading

    private val _isAddingRoom = MutableStateFlow(false)
    val isAddingRoom: StateFlow<Boolean> = _isAddingRoom.asStateFlow()

    private val _addRoomError = MutableStateFlow<String?>(null)
    val addRoomError: StateFlow<String?> = _addRoomError.asStateFlow()

    fun addRoom(name: String, onDone: () -> Unit) {
        val propertyId = property.value?.id ?: return
        val userId = sessionManager.userId.value ?: return
        viewModelScope.launch {
            _isAddingRoom.value = true
            _addRoomError.value = null
            try {
                propertyStore.addRoom(propertyId, userId, name)
                onDone()
            } catch (e: Exception) {
                _addRoomError.value = e.message ?: "Couldn't add room. Try again."
            } finally {
                _isAddingRoom.value = false
            }
        }
    }

    fun clearAddRoomError() {
        _addRoomError.value = null
    }
}
