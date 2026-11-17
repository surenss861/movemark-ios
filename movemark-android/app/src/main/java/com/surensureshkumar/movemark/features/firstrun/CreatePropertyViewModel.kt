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

/**
 * First-run rental setup, as iOS FirstRunPropertySetupView builds it: no nickname and no personal name; the rental is
 * titled from its address ("88 Harbour St, Unit 1204"), the unit is stored as address_line_2, country is CA, and no
 * lease is invented from the move-in date.
 */
object FirstRunRentalSetup {
    private val unitPrefixes = listOf("unit", "apt", "suite", "#")

    /** iOS `FirstRunPropertySetupView.title(street:unit:)`: the street, then ", Unit X" unless the unit says its own kind. */
    fun title(street: String, unit: String): String {
        val s = street.trim()
        val u = unit.trim()
        if (u.isEmpty()) return s
        val hasPrefix = unitPrefixes.any { u.lowercase().startsWith(it) }
        return "$s, ${if (hasPrefix) u else "Unit $u"}"
    }

    fun input(street: String, unit: String, city: String, province: String, moveIn: LocalDate): CreatePropertyInput =
        CreatePropertyInput(
            title = title(street, unit),
            addressLine1 = street.trim(),
            unit = unit.trim(),
            city = city.trim(),
            region = province.trim(),
            postalCode = "",
            country = "CA",
            moveInDate = moveIn,
            leaseStart = null,
            leaseEnd = null,
        )
}

@HiltViewModel
class CreatePropertyViewModel @Inject constructor(
    private val sessionManager: SessionManager,
    private val propertyStore: PropertyStore,
) : ViewModel() {
    /** Add rental only (first-run setup has no nickname: the title comes from the address). */
    private val _title = MutableStateFlow("")
    val title: StateFlow<String> = _title.asStateFlow()
    private val _address = MutableStateFlow("")
    val address: StateFlow<String> = _address.asStateFlow()
    private val _unit = MutableStateFlow("")
    val unit: StateFlow<String> = _unit.asStateFlow()
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
    fun setUnit(v: String) { _unit.value = v }
    fun setCity(v: String) { _city.value = v }
    fun setRegion(v: String) { _region.value = v }

    /**
     * [askLease]: adding a rental asks for the lease (iOS NewPropertyView); first-run setup asks only for the move-in
     * date and leaves the lease unset rather than inventing one (iOS FirstRunPropertySetupView).
     */
    fun create(askLease: Boolean, onDone: () -> Unit) {
        if (_loading.value) return
        val userId = sessionManager.userId.value ?: return
        if (_address.value.trim().isEmpty()) {
            _error.value = "Enter the street address."
            return
        }
        if (askLease) RentalDates.leaseDatesError(_leaseStart.value, _leaseEnd.value)?.let {
            _error.value = it
            return
        }
        val input = if (askLease) {
            CreatePropertyInput(
                title = _title.value,
                addressLine1 = _address.value,
                unit = _unit.value,
                city = _city.value,
                region = _region.value,
                postalCode = "",
                moveInDate = _moveIn.value,
                leaseStart = _leaseStart.value,
                leaseEnd = _leaseEnd.value,
            )
        } else {
            FirstRunRentalSetup.input(_address.value, _unit.value, _city.value, _region.value, _moveIn.value)
        }
        viewModelScope.launch {
            _loading.value = true
            _error.value = null
            try {
                propertyStore.createProperty(input, userId)
                onDone()
            } catch (e: Exception) {
                _error.value = MMUserMessages.createRental(e)
            } finally {
                _loading.value = false
            }
        }
    }
}
