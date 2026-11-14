package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.TextButton
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.Role
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy
import java.util.UUID

private enum class FirstRunRoomOption(val label: String, val defaultRoomName: String?) {
    Kitchen("Kitchen", "Kitchen"),
    LivingRoom("Living room", "Living Room"),
    Bedroom("Bedroom", "Primary Bedroom"),
    Bathroom("Bathroom", "Bathroom"),
    Hallway("Hallway", "Hallway"),
}

@Composable
fun FirstRunRoomPickerScreen(
    onStartProof: (UUID) -> Unit,
    onSkipToMain: () -> Unit,
    viewModel: FirstRunRoomPickerViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    var selected by remember { mutableStateOf(FirstRunRoomOption.Kitchen) }
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()

    MMScreen(
        title = MoveMarkGrowthCopy.FIRST_RUN_ROOM_TITLE,
        lines = listOf(MoveMarkGrowthCopy.FIRST_RUN_ROOM_SUBTITLE),
    ) {
        MMGroup(modifier = Modifier.selectableGroup()) {
            FirstRunRoomOption.entries.forEachIndexed { index, option ->
                if (index > 0) MMRowDivider()
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 52.dp)
                        .selectable(selected = selected == option, role = Role.RadioButton) { selected = option }
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(option.label, style = mmFont(16f), color = MMInk.Text, modifier = Modifier.weight(1f))
                    RadioButton(
                        selected = selected == option,
                        onClick = null,
                        colors = RadioButtonDefaults.colors(selectedColor = MMInk.Text, unselectedColor = MMInk.Secondary),
                    )
                }
            }
        }
        error?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MMInk.Danger, fontSize = 14.sp)
        }
        Spacer(Modifier.height(24.dp))
        MMPrimaryButton(
            title = if (loading) "Opening room…" else "Start room proof",
            onClick = {
                val p = property ?: return@MMPrimaryButton
                val roomName = selected.defaultRoomName ?: selected.label
                val room = p.rooms.firstOrNull { it.name.equals(roomName, ignoreCase = true) }
                    ?: p.rooms.firstOrNull()
                room?.let { onStartProof(it.id) }
            },
            isLoading = loading,
            enabled = property != null && !loading,
        )
        TextButton(
            onClick = { viewModel.markFirstRunComplete { onSkipToMain() } },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(top = 4.dp),
        ) { Text("Skip for now", style = mmFont(15f, FontWeight.Medium), color = MMInk.Text) }
    }
}
