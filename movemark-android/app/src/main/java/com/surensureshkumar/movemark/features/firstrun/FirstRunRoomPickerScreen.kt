package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import java.util.UUID

const val OTHER_ROOM_SHEET_TITLE = "Add another room"
const val OTHER_ROOM_SHEET_LINE = "Name the space. You'll photograph it next."

/**
 * iOS FirstRunRoomPickerView: six options (the five default rooms and "Other"), one action. No skip: iOS first run has
 * no skip, later or not-now anywhere; the way out is the moment picker's Sign out.
 */
@Composable
fun FirstRunRoomPickerScreen(
    onStartProof: (UUID) -> Unit,
    /** Back to the moment picker (or setup when no rental exists yet). */
    onBack: (() -> Unit)? = null,
    viewModel: FirstRunRoomPickerViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    var selected by rememberSaveable { mutableStateOf(FirstRunRoomOption.Kitchen) }
    var otherRoomName by rememberSaveable { mutableStateOf("") }
    var showOtherSheet by rememberSaveable { mutableStateOf(false) }

    fun start() {
        if (FirstRunRoomChoice.needsOtherSheet(selected, otherRoomName)) {
            showOtherSheet = true
            return
        }
        viewModel.startRoomProof(selected, otherRoomName, onStartProof)
    }

    FirstRunRoomPickerContent(
        selected = selected,
        onSelect = {
            selected = it
            viewModel.clearError()
        },
        error = error,
        loading = loading,
        canStart = property != null,
        onStart = { start() },
        onBack = if (loading) null else onBack,
    )

    if (showOtherSheet) {
        FirstRunOtherRoomSheet(
            otherRoomName = otherRoomName,
            onNameChange = { otherRoomName = it },
            onUse = {
                showOtherSheet = false
                start()
            },
            onDismiss = { showOtherSheet = false },
        )
    }
}

/** The picker itself, stateless (Robolectric-tested). */
@Composable
fun FirstRunRoomPickerContent(
    selected: FirstRunRoomOption,
    onSelect: (FirstRunRoomOption) -> Unit,
    error: String?,
    loading: Boolean,
    canStart: Boolean,
    onStart: () -> Unit,
    onBack: (() -> Unit)? = null,
) {
    MMScreen(
        title = MoveMarkGrowthCopy.FIRST_RUN_ROOM_TITLE,
        lines = listOf(MoveMarkGrowthCopy.FIRST_RUN_ROOM_SUBTITLE),
        onBack = onBack,
    ) {
        MMGroup(modifier = Modifier.selectableGroup()) {
            FirstRunRoomOption.entries.forEachIndexed { index, option ->
                if (index > 0) MMRowDivider()
                FirstRunSelectRow(
                    title = option.label,
                    selected = selected == option,
                    tag = "firstRun.room.${option.name}",
                    onClick = { onSelect(option) },
                )
            }
        }
        error?.let {
            Spacer(Modifier.height(22.dp))
            MMNotice(it)
        }
        Spacer(Modifier.height(26.dp))
        MMPrimaryButton(
            title = "Start room proof",
            onClick = onStart,
            isLoading = loading,
            enabled = canStart && !loading,
            modifier = Modifier.testTag("firstRun.startRoomProof"),
        )
    }
}

/** iOS FirstRunOtherRoomSheet: name the room (or pick a suggestion), then go straight into its capture. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FirstRunOtherRoomSheet(
    otherRoomName: String,
    onNameChange: (String) -> Unit,
    onUse: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MMInk.Sheet,
    ) {
        FirstRunOtherRoomSheetContent(otherRoomName, onNameChange, onUse, onCancel = onDismiss)
    }
}

/** The sheet's content, stateless (Robolectric-tested without a bottom-sheet window). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FirstRunOtherRoomSheetContent(
    otherRoomName: String,
    onNameChange: (String) -> Unit,
    onUse: () -> Unit,
    onCancel: () -> Unit,
) {
    val isNameEmpty = otherRoomName.isBlank()
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = MMMetrics.Inset)
            .padding(bottom = 24.dp),
    ) {
        Text(
            OTHER_ROOM_SHEET_TITLE,
            style = mmFont(20f, FontWeight.SemiBold),
            color = MMInk.Text,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            OTHER_ROOM_SHEET_LINE,
            style = mmFont(15f),
            color = MMInk.Secondary,
            modifier = Modifier.padding(top = 8.dp),
        )
        FirstRunField(
            title = "Room name",
            placeholder = "e.g. Office",
            value = otherRoomName,
            onValueChange = onNameChange,
            imeAction = ImeAction.Done,
            onImeAction = { if (!isNameEmpty) onUse() },
            tag = "firstRun.otherRoomName",
            modifier = Modifier.padding(top = 18.dp),
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 6.dp),
        ) {
            FirstRunRoomChoice.OTHER_ROOM_SUGGESTIONS.forEach { name ->
                val isSelected = FirstRunRoomChoice.isSuggestionSelected(otherRoomName, name)
                FirstRunChip(title = name, selected = isSelected) {
                    if (!isSelected) onNameChange(name)
                }
            }
        }
        MMPrimaryButton(
            title = "Add room",
            onClick = onUse,
            enabled = !isNameEmpty,
            modifier = Modifier
                .padding(top = 22.dp)
                .testTag("firstRun.addOtherRoom"),
        )
        // iOS puts Cancel in the sheet's toolbar; here it sits under the action.
        MMSecondaryButton(title = "Cancel", onClick = onCancel, tint = MMInk.Secondary)
    }
}
