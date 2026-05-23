package com.surensureshkumar.movemark.features.rooms

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMRoomProofRow
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.util.UUID

@Composable
fun RoomsScreen(
    onOpenRoom: (UUID) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: RoomsViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val reduceMotion = MMMotion.rememberReduceMotion()
    var hasAnimatedIn by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) hasAnimatedIn = true
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            .padding(top = 24.dp, bottom = MMSpacing.TabScrollBottom.dp),
    ) {
        MMProofSectionHeader(
            title = "Room proof",
            subtitle = "Document each room with photos.",
            modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "roomsHeader"),
        )
        Spacer(Modifier.height(16.dp))
        when {
            loading -> CircularProgressIndicator(color = MMColors.Primary)
            property == null -> Text("No rooms loaded.", color = MMColors.TextSecondary)
            else -> {
                val p = property!!
                val documented = RoomProofMetrics.documentedCount(p)
                Text(
                    "$documented of ${p.rooms.size} rooms ready",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "roomsCount"),
                )
                Spacer(Modifier.height(16.dp))
                val nextId = RoomProofMetrics.nextRoom(p)?.id
                p.rooms.forEachIndexed { index, room ->
                    MMRoomProofRow(
                        room = room,
                        index = index + 1,
                        isNext = room.id == nextId,
                        onClick = { onOpenRoom(room.id) },
                        modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "room${room.id}"),
                    )
                }
                nextId?.let { id ->
                    val next = p.rooms.first { it.id == id }
                    Spacer(Modifier.height(8.dp))
                    MMButton(
                        text = "Capture ${next.name}",
                        onClick = { onOpenRoom(next.id) },
                    )
                }
            }
        }
    }
}
