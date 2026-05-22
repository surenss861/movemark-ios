package com.surensureshkumar.movemark.features.proof

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import java.util.UUID

@Composable
fun RoomProofScreen(
    roomId: UUID,
    onBack: () -> Unit,
    onProofSaved: (UUID) -> Unit,
    viewModel: RoomProofViewModel = hiltViewModel(),
) {
    val room by viewModel.room.collectAsState()
    val photoCount by viewModel.photoCount.collectAsState()
    val uploading by viewModel.uploading.collectAsState()
    val message by viewModel.message.collectAsState()
    LaunchedEffect(Unit) {
        viewModel.proofSaved.collect { payload -> onProofSaved(payload.roomId) }
    }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(12),
    ) { uris ->
        if (uris.isNotEmpty()) viewModel.addUris(uris)
    }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 24.dp),
        ) {
            TextButton(onClick = onBack) { Text("Back", color = MMColors.TextSecondary) }
            Text(
                text = room?.name ?: "Room",
                style = androidx.compose.material3.MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(8.dp))
            val documented = room?.let { RoomProofMetrics.isDocumented(it) } == true
            Text(
                text = when {
                    photoCount > 0 -> "$photoCount photos selected"
                    documented -> "Room has saved proof on file"
                    else -> "No photos yet"
                },
                color = MMColors.TextSecondary,
            )
            message?.let {
                Spacer(Modifier.height(8.dp))
                val isSuccess = it.startsWith("Proof saved")
                Text(it, color = if (isSuccess) MMColors.Primary else MMColors.SemanticDanger)
            }
            Spacer(Modifier.height(24.dp))
            MMButton(
                text = "Add photos",
                onClick = {
                    picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                style = MMButtonStyle.Secondary,
                enabled = !uploading,
            )
            Spacer(Modifier.height(12.dp))
            MMButton(
                text = if (uploading) "Saving…" else "Save proof",
                onClick = viewModel::save,
                loading = uploading,
                enabled = photoCount > 0,
            )
        }
    }
}
