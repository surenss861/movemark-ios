package com.surensureshkumar.movemark.features.firstrun

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.surensureshkumar.movemark.core.util.MMUserMessages
import com.surensureshkumar.movemark.data.auth.SessionManager
import com.surensureshkumar.movemark.data.models.CreatePropertyInput
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import com.surensureshkumar.movemark.domain.RentalDates
import java.time.LocalDate
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

    private val today = LocalDate.now()
    private val _moveIn = MutableStateFlow(today)
    val moveIn: StateFlow<LocalDate> = _moveIn.asStateFlow()
    private val _leaseStart = MutableStateFlow(today)
    val leaseStart: StateFlow<LocalDate> = _leaseStart.asStateFlow()
    private val _leaseEnd = MutableStateFlow(RentalDates.defaultLeaseEnd(today))
    val leaseEnd: StateFlow<LocalDate> = _leaseEnd.asStateFlow()

    fun setMoveIn(v: LocalDate) { _moveIn.value = v }
    fun setLeaseStart(v: LocalDate) { _leaseStart.value = v; _error.value = null }
    fun setLeaseEnd(v: LocalDate) { _leaseEnd.value = v; _error.value = null }

    fun setTitle(v: String) { _title.value = v }
    fun setAddress(v: String) { _address.value = v }
    fun setCity(v: String) { _city.value = v }
    fun setRegion(v: String) { _region.value = v }

    /**
     * [askLease]: adding a rental asks for the lease (iOS NewPropertyView); first-run setup asks only for the move-in
     * date and leaves the lease unset rather than inventing one (iOS FirstRunPropertySetupView).
     */
    fun create(askLease: Boolean, onDone: () -> Unit) {
        val userId = sessionManager.userId.value ?: return
        if (_address.value.trim().isEmpty()) {
            _error.value = "Enter a street address."
            return
        }
        if (askLease) RentalDates.leaseDatesError(_leaseStart.value, _leaseEnd.value)?.let {
            _error.value = it
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
                        moveInDate = _moveIn.value,
                        leaseStart = if (askLease) _leaseStart.value else null,
                        leaseEnd = if (askLease) _leaseEnd.value else null,
                    ),
                    userId,
                )
                onDone()
            } catch (e: Exception) {
                _error.value = MMUserMessages.createRental(e)
            } finally {
                _loading.value = false
            }
        }
    }
}
