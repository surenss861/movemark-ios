/**
 * @file First run, one route (iOS FirstRunProofFlowView.swift): moment → rental setup → room pick, then the room's
 *       capture opens on the nav stack in the moment's phase. Shown by StartupRouter's Onboarding destination: a
 *       server-confirmed empty rental listing, or a loaded rental whose first room isn't done yet. Never on an unknown or
 *       failed lookup.
 * @domain onboarding-auth
 * @status wip
 * @see [[StartupRouter.kt]]
 * @tested-by [[FirstRunFlowTest.kt]]
 */
package com.surensureshkumar.movemark.features.firstrun

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import com.surensureshkumar.movemark.data.property.PropertyStore
import com.surensureshkumar.movemark.domain.ProofPhase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID
import javax.inject.Inject

enum class FirstRunStep { Moment, Setup, PickRoom }

/** The flow's step rules (iOS FirstRunProofFlowView). Pure, unit-tested. */
object FirstRunFlow {
    /** After the moment: an existing rental goes straight to the room pick (no second rental), otherwise setup. */
    fun stepAfterMoment(hasRental: Boolean): FirstRunStep = if (hasRental) FirstRunStep.PickRoom else FirstRunStep.Setup

    /** Back from the room pick: to the moment when a rental exists (choosing again reuses it), else to setup. */
    fun backFromRoomPick(hasRental: Boolean): FirstRunStep = if (hasRental) FirstRunStep.Moment else FirstRunStep.Setup
}

@HiltViewModel
class FirstRunFlowViewModel @Inject constructor(
    propertyStore: PropertyStore,
) : ViewModel() {
    val hasCompletedInitialFetch: StateFlow<Boolean> = propertyStore.hasCompletedInitialFetch
    val properties = propertyStore.properties
    val currentProperty = propertyStore.currentProperty
}

@Composable
fun FirstRunFlowScreen(
    /** The chosen room's capture, in the moment's phase (move-out evidence for "Moving out"). */
    onStartProof: (roomId: UUID, phase: ProofPhase) -> Unit,
    onSignOut: () -> Unit,
    viewModel: FirstRunFlowViewModel = hiltViewModel(),
) {
    val fetched by viewModel.hasCompletedInitialFetch.collectAsState()
    val properties by viewModel.properties.collectAsState()
    val current by viewModel.currentProperty.collectAsState()
    // Saved across the trip to the capture and back, and across process death.
    var step by rememberSaveable { mutableStateOf(FirstRunStep.Moment) }
    var moment by rememberSaveable { mutableStateOf(RentalMoment.JustMovedIn) }
    val hasRental = current != null || properties.isNotEmpty()

    // System back walks the flow back like the header's back button; on the moment it leaves the app as usual.
    BackHandler(enabled = step == FirstRunStep.Setup) { step = FirstRunStep.Moment }
    BackHandler(enabled = step == FirstRunStep.PickRoom) { step = FirstRunFlow.backFromRoomPick(hasRental) }

    when (step) {
        FirstRunStep.Moment -> FirstRunMomentPickerScreen(
            isPreparing = !fetched,
            onSelect = { chosen ->
                moment = chosen
                step = FirstRunFlow.stepAfterMoment(hasRental)
            },
            onSignOut = onSignOut,
        )
        FirstRunStep.Setup -> CreatePropertyScreen(
            onCreated = { step = FirstRunStep.PickRoom },
            onBack = { step = FirstRunStep.Moment },
        )
        FirstRunStep.PickRoom -> FirstRunRoomPickerScreen(
            onStartProof = { roomId -> onStartProof(roomId, moment.proofPhase) },
            onBack = { step = FirstRunFlow.backFromRoomPick(hasRental) },
        )
    }
}
