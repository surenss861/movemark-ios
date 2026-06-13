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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMRoomProgressCard
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
            subtitle = "Mark old damage before move-in.",
            modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "roomsHeader"),
        )
        Spacer(Modifier.height(16.dp))
        when {
            loading -> CircularProgressIndicator(color = MMColors.Primary)
            property == null -> Text("No rooms loaded.", color = MMColors.TextSecondary)
            else -> {
                val p = property!!
                val total = p.rooms.size
                val documented = RoomProofMetrics.documentedCount(p)
                val next = RoomProofMetrics.nextRoom(p)
                val allDocumented = total > 0 && documented >= total
                val progress = if (total > 0) documented.toFloat() / total else 0f
                val headline = if (total > 0) {
                    "$documented of $total rooms documented"
                } else {
                    "Add a room to start"
                }
                val nextLine = when {
                    allDocumented -> "All rooms documented"
                    next != null -> "Next: ${next.name}"
                    else -> "Add a room to start."
                }
                val primaryTitle = when {
                    allDocumented -> "Review your rooms"
                    next != null -> "Capture ${next.name}"
                    else -> "Add a room"
                }

                MMRoomProgressCard(
                    headline = headline,
                    nextLine = nextLine,
                    progress = progress,
                    primaryTitle = primaryTitle,
                    onPrimary = {
                        (next ?: p.rooms.firstOrNull())?.let { onOpenRoom(it.id) }
                    },
                    reduceMotion = reduceMotion,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "roomsProgress"),
                )

                Spacer(Modifier.height(20.dp))
                Text(
                    "Rooms",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.TextSecondary,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "roomsLabel"),
                )
                Spacer(Modifier.height(12.dp))

                val nextId = next?.id
                p.rooms.forEachIndexed { index, room ->
                    MMRoomProofRow(
                        room = room,
                        index = index + 1,
                        isNext = room.id == nextId,
                        onClick = { onOpenRoom(room.id) },
                        modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "room${room.id}"),
                    )
                }
            }
        }
    }
}
