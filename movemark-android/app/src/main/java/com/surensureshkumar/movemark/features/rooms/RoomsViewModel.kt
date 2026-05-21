package com.surensureshkumar.movemark.features.rooms

import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.data.models.PropertyRecord
import com.surensureshkumar.movemark.data.property.PropertyStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class RoomsViewModel @Inject constructor(
    propertyStore: PropertyStore,
) : ViewModel() {
    val property: StateFlow<PropertyRecord?> = propertyStore.currentProperty
    val loading: StateFlow<Boolean> = propertyStore.isLoading
}
