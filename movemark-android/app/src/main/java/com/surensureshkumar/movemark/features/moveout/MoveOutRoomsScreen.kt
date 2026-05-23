package com.surensureshkumar.movemark.features.moveout

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMRoomProofRow
import com.surensureshkumar.movemark.domain.ProofPhase
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.util.UUID

@Composable
fun MoveOutRoomsScreen(
    onBack: () -> Unit,
    onOpenRoom: (UUID) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: MoveOutRoomsViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val loading by viewModel.loading.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
    ) {
        TextButton(onClick = onBack) { Text("Back", color = MMColors.TextSecondary) }
        MMProofSectionHeader(
            title = "Move-out proof",
            subtitle = "Capture each room before you return the keys.",
        )
        Spacer(Modifier.height(16.dp))
        when {
            loading -> CircularProgressIndicator(color = MMColors.Primary)
            property == null -> Text("No rental loaded.", color = MMColors.TextSecondary)
            else -> {
                val p = property!!
                val documented = RoomProofMetrics.moveOutDocumentedCount(p)
                Text(
                    "$documented of ${p.rooms.size} rooms with move-out proof",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                )
                Spacer(Modifier.height(16.dp))
                val nextId = RoomProofMetrics.nextRoom(p, ProofPhase.MoveOut)?.id
                p.rooms.forEachIndexed { index, room ->
                    MMRoomProofRow(
                        room = room,
                        index = index + 1,
                        isNext = room.id == nextId,
                        onClick = { onOpenRoom(room.id) },
                        proofPhase = ProofPhase.MoveOut,
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
