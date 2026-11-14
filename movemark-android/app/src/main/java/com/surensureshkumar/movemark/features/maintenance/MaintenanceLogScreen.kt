package com.surensureshkumar.movemark.features.maintenance

import androidx.compose.ui.graphics.Color
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMScreen
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.data.models.MaintenanceRecord
import java.util.UUID

private val CATEGORIES = listOf(
    "Plumbing", "Electrical", "Appliance", "HVAC", "Structural", "Pests", "Other",
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MaintenanceLogScreen(
    onBack: () -> Unit,
    onOpenIssue: (UUID) -> Unit,
    viewModel: MaintenanceLogViewModel = hiltViewModel(),
) {
    val log by viewModel.maintenanceLog.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isSubmitting by viewModel.isSubmitting.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    var title by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("General") }
    var details by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { viewModel.refresh() }

    val openIssues = log.filter { it.status != "resolved" }
    val resolvedIssues = log.filter { it.status == "resolved" }

    // 1.4 grammar (iOS maintenance in MMScreen): header with back, composer and cases on the light sheet.
    MMScreen(
        title = "Maintenance",
        lines = listOf("Track issues and landlord follow-up."),
        onBack = onBack,
    ) {
            // Composer card
            run {
                Column(
                    modifier = Modifier
                        
                        .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .background(Color.White)
                        .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
                        .padding(16.dp),
                ) {
                    Text(
                        text = "Log a new incident",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Text,
                    )
                    Spacer(Modifier.height(12.dp))
                    MMTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = "Title",
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "Category",
                        fontSize = 13.sp,
                        color = MMInk.Secondary,
                    )
                    Spacer(Modifier.height(6.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        CATEGORIES.forEach { cat ->
                            val isSelected = cat == selectedCategory
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(if (isSelected) MMInk.Text else MMInk.Field)
                                    .border(
                                        1.dp,
                                        if (isSelected) MMInk.Text else MMInk.CardStroke,
                                        RoundedCornerShape(20.dp),
                                    )
                                    .clickable { selectedCategory = cat }
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                            ) {
                                Text(
                                    text = cat,
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                    color = if (isSelected) androidx.compose.ui.graphics.Color.White else MMInk.Secondary,
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = details,
                        onValueChange = { details = it },
                        label = { Text("Details") },
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

                    errorMessage?.let { msg ->
                        Spacer(Modifier.height(8.dp))
                        Text(msg, color = MMInk.Danger, fontSize = 13.sp)
                    }

                    Spacer(Modifier.height(14.dp))
                    MMPrimaryButton(
                        title = "Save incident",
                        onClick = {
                            viewModel.addIncident(title, selectedCategory, details)
                            title = ""
                            details = ""
                            selectedCategory = "General"
                        },
                        isLoading = isSubmitting,
                        enabled = title.isNotBlank() && !isSubmitting,
                    )
                }
                Spacer(Modifier.height(24.dp))
            }

            // Open incidents header
            run {
                if (openIssues.isNotEmpty()) {
                    Text(
                        text = "Open incidents",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Secondary,
                        modifier = Modifier,
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }

            // Open issues
            openIssues.forEach { record ->
                MaintenanceIssueRow(
                    record = record,
                    onClick = { onOpenIssue(record.id) },
                )
                Spacer(Modifier.height(8.dp))
            }

            // Resolved header
            run {
                if (resolvedIssues.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = "Resolved",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMInk.Secondary,
                        modifier = Modifier,
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }

            // Resolved issues
            resolvedIssues.forEach { record ->
                MaintenanceIssueRow(
                    record = record,
                    onClick = { onOpenIssue(record.id) },
                )
                Spacer(Modifier.height(8.dp))
            }

            // Loading indicator
            run {
                if (isLoading && log.isEmpty()) {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = MMInk.Text)
                    }
                }
            }

            run {
                if (!isLoading && log.isEmpty()) {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        Text(
                            "No incidents logged yet.\nLog your first issue above.",
                            color = MMInk.Secondary,
                            fontSize = 15.sp,
                        )
                    }
                }
            }

        }
}

@Composable
private fun MaintenanceIssueRow(
    record: MaintenanceRecord,
    onClick: () -> Unit,
) {
    val isResolved = record.status == "resolved"
    Row(
        modifier = Modifier
            
            .fillMaxWidth()
            .clip(RoundedCornerShape(MMSpacing.CornerRadius.dp))
            .background(Color.White)
            .border(0.75.dp, MMInk.CardStroke, RoundedCornerShape(MMSpacing.CornerRadius.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f)) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Category chip
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(MMInk.Field)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                ) {
                    Text(record.category, fontSize = 11.sp, color = MMInk.Secondary)
                }
                // Status chip
                val statusBg = if (isResolved) MMInk.Text.copy(alpha = 0.15f) else MMInk.Warning.copy(alpha = 0.18f)
                val statusColor = if (isResolved) MMInk.Text else MMInk.Warning
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(statusBg)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                ) {
                    Text(
                        text = if (isResolved) "Resolved" else "Open",
                        fontSize = 11.sp,
                        color = statusColor,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = record.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMInk.Text,
            )
            if (record.details.isNotBlank()) {
                Spacer(Modifier.height(3.dp))
                Text(
                    text = record.details,
                    fontSize = 13.sp,
                    color = MMInk.Secondary,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            record.createdAt?.let { dateStr ->
                val formatted = dateStr.take(10)
                Spacer(Modifier.height(4.dp))
                Text(
                    text = formatted,
                    fontSize = 11.sp,
                    color = MMInk.Secondary,
                )
            }
        }
        Spacer(Modifier.width(8.dp))
        Text(
            text = ">",
            fontSize = 16.sp,
            color = MMInk.Secondary,
        )
    }
}
