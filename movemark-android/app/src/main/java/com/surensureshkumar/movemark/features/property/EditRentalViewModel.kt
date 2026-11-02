package com.surensureshkumar.movemark.features.property

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.RentalEditForm
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/** Edit rental (iOS `EditPropertyView`): the active rental's fields, saved with one patch. */
@HiltViewModel
class EditRentalViewModel @Inject constructor(
    private val propertyStore: PropertyStore,
    private val sessionManager: SessionManager,
) : ViewModel() {
    private val propertyId: UUID? = propertyStore.activePropertyId.value
    val initial: RentalEditForm = propertyStore.properties.value
        .firstOrNull { it.id.equals(propertyId?.toString(), ignoreCase = true) }
        ?.let(RentalEditForm::from) ?: RentalEditForm()

    private val _form = MutableStateFlow(initial)
    val form: StateFlow<RentalEditForm> = _form.asStateFlow()

    private val _saving = MutableStateFlow(false)
    val saving: StateFlow<Boolean> = _saving.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    val hasChanges: Boolean get() = _form.value != initial

    fun update(transform: (RentalEditForm) -> RentalEditForm) {
        _form.value = transform(_form.value)
        _error.value = null
    }

    fun save(onSaved: () -> Unit) {
        val id = propertyId ?: return
        val userId = sessionManager.userId.value ?: return
        val form = _form.value
        if (!form.canSave(initial) || _saving.value) return
        viewModelScope.launch {
            _saving.value = true
            try {
                propertyStore.updateProperty(id, form.toPatch(), userId)
                onSaved()
            } catch (e: Exception) {
                _error.value = "Couldn't save your changes. Try again."
            } finally {
                _saving.value = false
            }
        }
    }
}
