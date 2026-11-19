package com.surensureshkumar.movemark.features.firstrun

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.models.RoomRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.core.util.MMUserMessages
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/** iOS FirstRunRoomOption: the five default rooms plus "Other", which names a room of its own. */
enum class FirstRunRoomOption(val label: String, val defaultRoomName: String?) {
    Kitchen("Kitchen", "Kitchen"),
    LivingRoom("Living room", "Living Room"),
    Bedroom("Primary bedroom", "Primary Bedroom"),
    Bathroom("Bathroom", "Bathroom"),
    Hallway("Hallway", "Hallway"),
    Other("Other", null),
}

/** How the room picker turns a choice into a room (iOS FirstRunRoomPickerView.resolveRoom). Pure, unit-tested. */
object FirstRunRoomChoice {
    /** The "Add another room" suggestions, word for word. */
    val OTHER_ROOM_SUGGESTIONS = listOf("Office", "Balcony", "Laundry", "Storage")

    /** The room name a choice stands for, or null when "Other" has no name yet (the sheet opens instead). */
    fun targetName(option: FirstRunRoomOption, otherRoomName: String): String? =
        if (option == FirstRunRoomOption.Other) otherRoomName.trim().takeIf { it.isNotEmpty() } else option.defaultRoomName

    /** "Other" with no name opens the sheet rather than starting proof. */
    fun needsOtherSheet(option: FirstRunRoomOption, otherRoomName: String): Boolean =
        option == FirstRunRoomOption.Other && otherRoomName.isBlank()

    /** An existing room with that name (case-insensitive), so a second tap never adds a duplicate. */
    fun existing(rooms: List<RoomRecord>, name: String): RoomRecord? =
        rooms.firstOrNull { it.name.trim().equals(name.trim(), ignoreCase = true) }

    /** A suggestion chip shows selected while the field holds its name (iOS compares case-insensitively). */
    fun isSuggestionSelected(otherRoomName: String, suggestion: String): Boolean =
        otherRoomName.trim().equals(suggestion, ignoreCase = true)
}

@HiltViewModel
class FirstRunRoomPickerViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
) : ViewModel() {

    /** The active rental, live: it is created a step earlier in the same flow. */
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty

    private val _loading = MutableStateFlow(false)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        viewModelScope.launch {
            val userId = sessionManager.userId.value ?: return@launch
            if (propertyStore.hasCompletedInitialFetch.value && propertyStore.currentProperty.value != null) return@launch
            _loading.value = true
            runCatching { propertyStore.fetchAll(userId) }
                .onFailure { _error.value = MMUserMessages.loadRentals(it) }
            _loading.value = false
        }
    }

    /**
     * Finds the chosen room on the rental, adding it when the rental doesn't have it yet (an "Other" room, or a default
     * room removed earlier), then hands its id to [onStart]. Uses the same add path as Rooms (PropertyStore.addRoom).
     */
    fun startRoomProof(option: FirstRunRoomOption, otherRoomName: String, onStart: (UUID) -> Unit) {
        if (_loading.value) return
        // A signed-in screen never shows a red "Sign in to continue." (unslop audit); the session is restoring.
        val userId = sessionManager.userId.value ?: return
        val name = FirstRunRoomChoice.targetName(option, otherRoomName) ?: run {
            _error.value = if (option == FirstRunRoomOption.Other) "Enter a room name." else "Pick a room to continue."
            return
        }
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            try {
                val current = propertyStore.currentProperty.value
                if (current == null) {
                    _error.value = "Couldn’t open your rental record. Try again."
                    return@launch
                }
                FirstRunRoomChoice.existing(current.rooms, name)?.let {
                    onStart(it.id)
                    return@launch
                }
                propertyStore.addRoom(current.id, userId, name)
                val added = propertyStore.currentProperty.value?.rooms?.let { FirstRunRoomChoice.existing(it, name) }
                if (added == null) {
                    _error.value = if (option == FirstRunRoomOption.Other) {
                        "Couldn’t add that room. Try again."
                    } else {
                        "Couldn’t open $name. Try again."
                    }
                } else {
                    onStart(added.id)
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: PropertyStore.InvalidRoomNameException) {
                _error.value = "Enter a room name."
            } catch (e: Exception) {
                _error.value = MMUserMessages.friendly(e, "Couldn’t add that room. Try again.")
            } finally {
                _loading.value = false
            }
        }
    }

    fun clearError() {
        _error.value = null
    }
}
