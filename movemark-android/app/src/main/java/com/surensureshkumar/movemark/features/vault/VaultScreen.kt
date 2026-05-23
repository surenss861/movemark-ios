package com.surensureshkumar.movemark.features.vault

import androidx.compose.foundation.clickable
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
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMButtonStyle
import com.surensureshkumar.movemark.core.design.components.MMCompactProofRow
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone
import com.surensureshkumar.movemark.core.design.components.MMProofTaskCard
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMVaultProofHeroCard
import com.surensureshkumar.movemark.data.models.PropertyRow
import com.surensureshkumar.movemark.domain.RoomProofMetrics
import com.surensureshkumar.movemark.features.subscription.PaywallReason
import java.util.UUID

@Composable
fun VaultScreen(
    onOpenRoom: (UUID) -> Unit,
    onOpenMoveOutProof: () -> Unit,
    onAddProperty: () -> Unit,
    onShowPaywall: (PaywallReason) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: VaultViewModel = hiltViewModel(),
) {
    val property by viewModel.property.collectAsState()
    val properties by viewModel.properties.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    val hasPro by viewModel.hasPro.collectAsState()
    val propertyCount by viewModel.propertyCount.collectAsState()
    val previewImageUrl by viewModel.previewImageUrl.collectAsState()
    val reduceMotion = MMMotion.rememberReduceMotion()
    var hasAnimatedIn by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) {
            hasAnimatedIn = true
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
            .padding(top = 10.dp, bottom = MMSpacing.TabScrollBottom.dp),
    ) {
        MMProofSectionHeader(
            title = "Your proof",
            subtitle = "What rental needs proof next?",
            modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "vaultHeader"),
            trailingAction = {
                TextButton(onClick = {
                    if (!hasPro && propertyCount >= 1) {
                        onShowPaywall(PaywallReason.ExtraProperty)
                    } else {
                        onAddProperty()
                    }
                }) {
                    Text("Add", color = MMColors.Primary, fontWeight = FontWeight.SemiBold)
                }
            },
        )
        Spacer(Modifier.height(16.dp))

        when {
            loading && property == null -> {
                CircularProgressIndicator(color = MMColors.Primary)
                Spacer(Modifier.height(12.dp))
                Text("Loading your proof vault…", color = MMColors.TextSecondary, fontSize = 15.sp)
            }
            error != null -> {
                Text(error!!, color = MMColors.SemanticDanger)
            }
            property == null -> {
                Text(
                    "Add your rental, then document each room before you settle in.",
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                )
                Spacer(Modifier.height(16.dp))
                MMButton(text = "Start move-in proof", onClick = onAddProperty)
            }
            else -> {
                val p = property!!
                val documented = RoomProofMetrics.documentedCount(p)
                val total = p.rooms.size
                val next = RoomProofMetrics.nextRoom(p)
                val progress = if (total > 0) documented.toFloat() / total else 0f
                val location = listOf(p.city, p.provinceState).filter { it.isNotBlank() }.joinToString(", ")
                val nextLine = next?.let { "Next: ${it.name}" }
                    ?: if (documented >= total && total > 0) "All rooms documented"
                    else "Add rooms to document damage"
                val progressLine = when {
                    total == 0 -> "Add rooms to document damage"
                    documented == 0 -> "Start with one room"
                    else -> "$documented of $total rooms documented"
                }
                val primaryTitle = when {
                    documented == 0 -> "Start room proof"
                    next != null -> "Continue room proof"
                    else -> "Review rooms"
                }

                val featuredRoom = RoomProofMetrics.firstPreviewRoom(p)
                    ?: next
                    ?: p.rooms.firstOrNull { RoomProofMetrics.isDocumented(it) }
                val featuredPhotoCount = featuredRoom?.let { RoomProofMetrics.photoCount(it) } ?: 0

                MMVaultProofHeroCard(
                    propertyName = p.title,
                    location = location.ifBlank { null },
                    phaseLabel = "Move-in",
                    progressLine = progressLine,
                    nextLine = nextLine,
                    progress = progress,
                    primaryTitle = primaryTitle,
                    onPrimary = {
                        (next ?: p.rooms.firstOrNull())?.let { onOpenRoom(it.id) }
                    },
                    reduceMotion = reduceMotion,
                    previewImageUrl = previewImageUrl,
                    roomName = featuredRoom?.name ?: next?.name,
                    photoCount = featuredPhotoCount,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "vaultHero"),
                )

                Spacer(Modifier.height(12.dp))
                MMProofTaskCard(
                    title = "Lease & deposit records",
                    reason = "Helps if your deposit is questioned later.",
                    onClick = { /* future: lease docs */ },
                    showChevron = true,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "leaseCard"),
                )

                Spacer(Modifier.height(10.dp))
                MMProofTaskCard(
                    title = "Move-out proof",
                    reason = RoomProofMetrics.moveOutStatusLine(p),
                    onClick = {
                        if (hasPro) onOpenMoveOutProof() else onShowPaywall(PaywallReason.MoveOutProof)
                    },
                    statusLabel = if (hasPro) null else "Pro",
                    statusTone = MMProofStatusTone.Neutral,
                    modifier = Modifier.mmAppearRise(hasAnimatedIn, reduceMotion, label = "moveOutCard"),
                )

                val otherRentals = properties.filter { it.id != p.id.toString() }
                if (otherRentals.isNotEmpty()) {
                    Spacer(Modifier.height(20.dp))
                    Text(
                        "Other rentals",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MMColors.TextSecondary,
                    )
                    Spacer(Modifier.height(8.dp))
                    otherRentals.forEach { row ->
                        OtherRentalRow(
                            row = row,
                            onClick = {
                                viewModel.activateProperty(UUID.fromString(row.id))
                            },
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun OtherRentalRow(
    row: PropertyRow,
    onClick: () -> Unit,
) {
    val location = listOf(row.city, row.provinceState).filter { it.isNotBlank() }.joinToString(", ")
    MMCompactProofRow(
        title = row.title,
        subtitle = if (location.isNotBlank()) location else "Tap to switch vault",
        meta = "Tap to switch vault".takeIf { location.isNotBlank() },
        onClick = onClick,
    )
}
