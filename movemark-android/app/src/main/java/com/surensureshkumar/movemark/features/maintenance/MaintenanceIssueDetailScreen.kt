package com.surensureshkumar.movemark.features.maintenance

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
import androidx.compose.runtime.rememberCoroutineScope
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
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest
import com.surensureshkumar.movemark.core.util.toJpegBytes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
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
    val statusBg = if (isResolved) MMColors.Primary.copy(alpha = 0.15f) else MMColors.SemanticWarning.copy(alpha = 0.18f)
    val statusColor = if (isResolved) MMColors.Primary else MMColors.SemanticWarning

    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(6),
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        coroutineScope.launch {
            val bytes = withContext(Dispatchers.IO) {
                uris.mapNotNull { it.toJpegBytes(context) }
            }
            if (bytes.isNotEmpty()) viewModel.attachPhotos(bytes)
        }
    }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 12.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            TextButton(onClick = onBack) {
                Text("Back", color = MMColors.TextSecondary)
            }
            Spacer(Modifier.height(4.dp))

            // Accent bar
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.12f)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MMColors.Primary),
            )
            Spacer(Modifier.height(12.dp))

            Text(
                text = issue?.title ?: "Issue detail",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = MMColors.TextPrimary,
            )
            Text(
                text = "Issue detail, timeline, and follow-up.",
                fontSize = 15.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )

            Spacer(Modifier.height(20.dp))

            issue?.let { rec ->
                // Overview card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(MMColors.Card)
                        .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = "Overview",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextMuted,
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        // Category chip
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(MMColors.CardRaised)
                                .padding(horizontal = 10.dp, vertical = 4.dp),
                        ) {
                            Text(rec.category, fontSize = 12.sp, color = MMColors.TextSecondary)
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
                            color = MMColors.TextPrimary,
                        )
                    }
                    rec.createdAt?.let { dateStr ->
                        Spacer(Modifier.height(10.dp))
                        Text(
                            text = "Logged ${dateStr.take(10)}",
                            fontSize = 12.sp,
                            color = MMColors.TextMuted,
                        )
                    }
                    rec.landlordResponse?.takeIf { it.isNotBlank() }?.let { response ->
                        Spacer(Modifier.height(12.dp))
                        Text(
                            text = "Landlord response",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextMuted,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = response,
                            fontSize = 15.sp,
                            color = MMColors.TextPrimary,
                        )
                    }
                }

                Spacer(Modifier.height(16.dp))

                // Photos card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(MMColors.Card)
                        .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "Photos",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextMuted,
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
                            Text(if (isUploadingPhotos) "Uploading…" else "+ Add photos", color = MMColors.Primary, fontSize = 13.sp)
                        }
                    }
                    if (photos.isEmpty() && !isUploadingPhotos) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "No photos attached yet.",
                            color = MMColors.TextSecondary,
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
                                        .background(MMColors.CardRaised)
                                        .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(10.dp)),
                                ) {
                                    photo.signedUrl?.let { url ->
                                        AsyncImage(
                                            model = rememberSignedImageRequest(url, photo.displayPath),
                                            contentDescription = null,
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
                                        CircularProgressIndicator(color = MMColors.Primary)
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
                        .background(MMColors.Card)
                        .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = "Follow-up note",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextMuted,
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
                            focusedBorderColor = MMColors.Primary,
                            unfocusedBorderColor = MMColors.CardStroke,
                            focusedTextColor = MMColors.TextPrimary,
                            unfocusedTextColor = MMColors.TextPrimary,
                            focusedLabelColor = MMColors.TextSecondary,
                            unfocusedLabelColor = MMColors.TextMuted,
                            cursorColor = MMColors.Primary,
                            focusedContainerColor = MMColors.FieldFill,
                            unfocusedContainerColor = MMColors.FieldFill,
                        ),
                    )
                    Spacer(Modifier.height(12.dp))
                    MMButton(
                        text = "Save follow-up",
                        onClick = {
                            viewModel.saveFollowUp(followUpNote)
                            followUpNote = ""
                        },
                        loading = isUpdating,
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
                            .background(MMColors.Card)
                            .border(0.75.dp, MMColors.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                            .padding(16.dp),
                    ) {
                        Text(
                            text = "Status",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MMColors.TextMuted,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = "Mark this issue resolved once the landlord has addressed it.",
                            fontSize = 13.sp,
                            color = MMColors.TextSecondary,
                        )
                        Spacer(Modifier.height(12.dp))
                        MMButton(
                            text = "Mark resolved",
                            onClick = { viewModel.markResolved() },
                            style = MMButtonStyle.Secondary,
                            loading = isUpdating,
                            enabled = !isUpdating,
                        )
                    }
                    Spacer(Modifier.height(16.dp))
                }
            } ?: run {
                Text(
                    text = "Issue not found.",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                )
            }

            message?.let { msg ->
                Spacer(Modifier.height(8.dp))
                val isError = msg.contains("Couldn't", ignoreCase = true) ||
                    msg.contains("Enter", ignoreCase = true)
                Text(
                    text = msg,
                    color = if (isError) MMColors.SemanticDanger else MMColors.Primary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}
