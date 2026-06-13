package com.surensureshkumar.movemark.features.firstrun

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
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
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

    MMBackground {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 24.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            MMProofSectionHeader(
                title = MoveMarkGrowthCopy.FIRST_RUN_ROOM_TITLE,
                subtitle = MoveMarkGrowthCopy.FIRST_RUN_ROOM_SUBTITLE,
            )
            Spacer(Modifier.height(16.dp))
            FirstRunRoomOption.entries.forEach { option ->
                val isSelected = selected == option
                Text(
                    option.label,
                    modifier = Modifier
                        .padding(vertical = 10.dp)
                        .clickable { selected = option },
                    color = if (isSelected) MMColors.Primary else MMColors.TextPrimary,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    fontSize = 17.sp,
                )
            }
            error?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
            }
            Spacer(Modifier.height(24.dp))
            MMButton(
                text = if (loading) "Opening room…" else "Start room proof",
                onClick = {
                    val p = property ?: return@MMButton
                    val roomName = selected.defaultRoomName ?: selected.label
                    val room = p.rooms.firstOrNull { it.name.equals(roomName, ignoreCase = true) }
                        ?: p.rooms.firstOrNull()
                    room?.let { onStartProof(it.id) }
                },
                loading = loading,
                enabled = property != null && !loading,
            )
            Spacer(Modifier.height(12.dp))
            MMButton(
                text = "Skip for now",
                onClick = {
                    viewModel.markFirstRunComplete { onSkipToMain() }
                },
                enabled = !loading,
            )
        }
    }
}
