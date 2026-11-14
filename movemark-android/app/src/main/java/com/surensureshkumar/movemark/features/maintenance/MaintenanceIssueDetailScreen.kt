package com.surensureshkumar.movemark.features.maintenance

import androidx.compose.ui.graphics.Color
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun MaintenanceIssueDetailScreen(
    issueId: UUID,
    onBack: () -> Unit,
    viewModel: MaintenanceIssueDetailViewModel = hiltViewModel(),
) {
    val issue by viewModel.issue.collectAsState()
    val isUpdating by viewModel.isUpdating.collectAsState()
    val message by viewModel.message.collectAsState()
    val photos by viewModel.photos.collectAsState()
    val isUploadingPhotos by viewModel.isUploadingPhotos.collectAsState()

    var followUpNote by rememberSaveable { mutableStateOf("") }

    val isResolved = issue?.status == "resolved"
    val statusBg = if (isResolved) MMInk.Text.copy(alpha = 0.15f) else MMInk.Warning.copy(alpha = 0.18f)
    val statusColor = if (isResolved) MMInk.Text else MMInk.Warning

    val context = LocalContext.current
    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(6),
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        viewModel.attachPhotos(uris)
    }

    // 1.4 grammar (iOS issue detail in MMScreen): header with back and the issue title, the case on the light sheet.
    MMScreen(
        title = issue?.title ?: "Issue detail",
        lines = listOf("Issue detail, timeline, and follow-up."),
        onBack = onBack,
    ) {
            issue?.let { rec ->
                // Overview card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(Color.White)
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = "Overview",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Secondary,
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Category chip
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(MMInk.Field)
                                .padding(horizontal = 10.dp, vertical = 4.dp),
                        ) {
                            Text(rec.category, fontSize = 12.sp, color = MMInk.Secondary)
                        }
                        Spacer(Modifier.weight(1f))
                        // Status chip
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(statusBg)
                                .padding(horizontal = 10.dp, vertical = 4.dp),
                        ) {
                            Text(
                                text = if (isResolved) "Resolved" else "Open",
                                fontSize = 12.sp,
                                color = statusColor,
                                fontWeight = FontWeight.Medium,
                            )
                        }
                    }
                    if (rec.details.isNotBlank()) {
                        Spacer(Modifier.height(12.dp))
                        Text(
                            text = rec.details,
                            fontSize = 15.sp,
                            color = MMInk.Text,
                        )
                    }
                    rec.createdAt?.let { dateStr ->
                        Spacer(Modifier.height(10.dp))
                        Text(
                            text = "Logged ${dateStr.take(10)}",
                            fontSize = 12.sp,
                            color = MMInk.Secondary,
                        )
                    }
                    rec.landlordResponse?.takeIf { it.isNotBlank() }?.let { response ->
                        Spacer(Modifier.height(12.dp))
                        Text(
                            text = "Landlord response",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMInk.Secondary,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = response,
                            fontSize = 15.sp,
                            color = MMInk.Text,
                        )
                    }
                }

                Spacer(Modifier.height(16.dp))

                // Photos card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(Color.White)
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "Photos",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMInk.Secondary,
                        )
                        Spacer(Modifier.weight(1f))
                        TextButton(
                            onClick = {
                                photoPicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                )
                            },
                            enabled = !isUploadingPhotos,
                        ) {
                            Text(if (isUploadingPhotos) "Uploading…" else "+ Add photos", color = MMInk.Text, fontSize = 13.sp)
                        }
                    }
                    if (photos.isEmpty() && !isUploadingPhotos) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "No photos attached yet.",
                            color = MMInk.Secondary,
                            fontSize = 13.sp,
                        )
                    } else {
                        Spacer(Modifier.height(10.dp))
                        LazyRow {
                            items(photos, key = { it.id.toString() }) { photo ->
                                Box(
                                    modifier = Modifier
                                        .padding(end = 8.dp)
                                        .size(72.dp)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(MMInk.Field)
                                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(10.dp)),
                                ) {
                                    photo.signedUrl?.let { url ->
                                        AsyncImage(
                                            model = rememberSignedImageRequest(url, photo.displayPath),
                                            contentDescription = "Maintenance photo",
                                            modifier = Modifier.fillMaxSize(),
                                        )
                                    }
                                }
                            }
                            if (isUploadingPhotos) {
                                item {
                                    Box(
                                        modifier = Modifier.size(72.dp),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        CircularProgressIndicator(color = MMInk.Text)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))

                // Follow-up card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(Color.White)
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = "Follow-up note",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Secondary,
                    )
                    Spacer(Modifier.height(10.dp))
                    OutlinedTextField(
                        value = followUpNote,
                        onValueChange = { followUpNote = it },
                        label = { Text("Landlord response or follow-up") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(100.dp),
                        shape = RoundedCornerShape(16.dp),
                        maxLines = 5,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = MMInk.Text,
                            unfocusedBorderColor = MMInk.CardStroke,
                            focusedTextColor = MMInk.Text,
                            unfocusedTextColor = MMInk.Text,
                            focusedLabelColor = MMInk.Secondary,
                            unfocusedLabelColor = MMInk.Secondary,
                            cursorColor = MMInk.Text,
                            focusedContainerColor = Color.White,
                            unfocusedContainerColor = Color.White,
                        ),
                    )
                    Spacer(Modifier.height(12.dp))
                    MMPrimaryButton(
                        title = "Save follow-up",
                        onClick = {
                            viewModel.saveFollowUp(followUpNote)
                            followUpNote = ""
                        },
                        isLoading = isUpdating,
                        enabled = followUpNote.isNotBlank() && !isUpdating,
                    )
                }

                Spacer(Modifier.height(16.dp))

                // Status card — only if not resolved
                if (!isResolved) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                            .background(Color.White)
                            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                            .padding(16.dp),
                    ) {
                        Text(
                            text = "Status",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMInk.Secondary,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = "Mark this issue resolved once the landlord has addressed it.",
                            fontSize = 13.sp,
                            color = MMInk.Secondary,
                        )
                        Spacer(Modifier.height(12.dp))
                        MMSecondaryButton(
                            title = if (isUpdating) "Saving…" else "Mark resolved",
                            onClick = { viewModel.markResolved() },
                            enabled = !isUpdating,
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                }
            } ?: run {
                Text(
                    text = "Issue not found.",
                    color = MMInk.Secondary,
                    fontSize = 15.sp,
                )
            }

            message?.let { msg ->
                Spacer(Modifier.height(8.dp))
                val isError = msg.contains("Couldn't", ignoreCase = true) ||
                    msg.contains("Enter", ignoreCase = true)
                Text(
                    text = msg,
                    color = if (isError) MMInk.Danger else MMInk.Text,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
}
