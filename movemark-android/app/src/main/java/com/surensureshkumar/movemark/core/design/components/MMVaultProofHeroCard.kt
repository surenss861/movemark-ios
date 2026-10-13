package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.util.rememberSignedImageRequest

private val ProofThumbnailBrightness = ColorMatrix(
    floatArrayOf(
        1.08f, 0f, 0f, 0f, 14f,
        0f, 1.08f, 0f, 0f, 14f,
        0f, 0f, 1.08f, 0f, 14f,
        0f, 0f, 0f, 1f, 0f,
    ),
)

@Composable
fun MMVaultProofHeroCard(
    propertyName: String,
    location: String?,
    phaseLabel: String,
    progressLine: String,
    nextLine: String,
    progress: Float,
    primaryTitle: String,
    onPrimary: () -> Unit,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
    previewImageUrl: String? = null,
    previewImagePath: String? = null,
    documentedCount: Int? = null,
    totalRooms: Int? = null,
    photoCount: Int? = null,
    recordCount: Int? = null,
    issueCount: Int? = null,
    lastProofLine: String? = null,
    reportReadyLine: String? = null,
    onViewReport: (() -> Unit)? = null,
) {
    val showsFigure = documentedCount != null && totalRooms != null && totalRooms > 0
    val nextName = nextLine.removePrefix("Next: ").takeIf { nextLine.startsWith("Next:") || nextLine.startsWith("Next: ") }

    MMCaseFilePlate(modifier = modifier, emphasis = true) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(
                    propertyName,
                    fontFamily = FontFamily.Serif,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MMColors.TextPrimary,
                    maxLines = 6,
                    overflow = TextOverflow.Ellipsis,
                )
                if (!location.isNullOrBlank()) {
                    Text(
                        location,
                        fontSize = 14.sp,
                        color = MMColors.TextSecondary,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            if (!previewImageUrl.isNullOrBlank()) {
                Spacer(Modifier.width(12.dp))
                ProofThumb(previewImageUrl, previewImagePath)
            }
        }

        Spacer(Modifier.height(18.dp))

        if (showsFigure) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MMCoverageFigure(
                    documented = documentedCount,
                    total = totalRooms,
                    kicker = "$phaseLabel coverage",
                    modifier = Modifier.weight(1f),
                )
                MMCoverageRing(progress = progress, reduceMotion = reduceMotion)
            }
        } else {
            Text(
                phaseLabel.uppercase(),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.1.sp,
                color = MMColors.TextMuted,
            )
            Text(
                progressLine,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.TextPrimary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        if (photoCount != null || recordCount != null || issueCount != null) {
            Spacer(Modifier.height(16.dp))
            Row(Modifier.fillMaxWidth()) {
                if (photoCount != null) {
                    StatCell(photoCount, if (photoCount == 1) "Photo" else "Photos", Modifier.weight(1f))
                }
                if (recordCount != null) {
                    StatCell(recordCount, if (recordCount == 1) "Record" else "Records", Modifier.weight(1f))
                }
                if (issueCount != null) {
                    StatCell(
                        issueCount,
                        if (issueCount == 1) "Issue" else "Issues",
                        Modifier.weight(1f),
                        valueColor = if (issueCount > 0) MMColors.SemanticWarning else MMColors.TextPrimary,
                    )
                }
            }
        }

        if (!lastProofLine.isNullOrBlank()) {
            Spacer(Modifier.height(16.dp))
            Text(
                "LAST PROOF ADDED",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.05.sp,
                color = MMColors.TextMuted,
            )
            Text(
                lastProofLine,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(top = 3.dp),
            )
        }

        Spacer(Modifier.height(14.dp))
        if (nextName != null) {
            Text(
                "NEXT",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.05.sp,
                color = MMColors.Primary,
            )
            Text(
                nextName,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.TextPrimary,
                modifier = Modifier.padding(top = 2.dp, bottom = 14.dp),
            )
        } else {
            Text(
                nextLine,
                fontSize = 14.sp,
                color = MMColors.TextSecondary,
                modifier = Modifier.padding(bottom = 14.dp),
            )
        }

        MMButton(text = primaryTitle, onClick = onPrimary, height = 52.dp)

        if (!reportReadyLine.isNullOrBlank() && onViewReport != null) {
            Spacer(Modifier.height(12.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onViewReport),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(reportReadyLine, fontSize = 14.sp, color = MMColors.TextSecondary, modifier = Modifier.weight(1f))
                Text("View", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = MMColors.Primary)
            }
        }
    }
}

@Composable
private fun StatCell(
    value: Int,
    label: String,
    modifier: Modifier = Modifier,
    valueColor: Color = MMColors.TextPrimary,
) {
    Column(modifier) {
        Text(
            value.toString(),
            fontFamily = FontFamily.Serif,
            fontSize = 22.sp,
            color = valueColor,
        )
        Text(
            label.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.8.sp,
            color = MMColors.TextMuted,
        )
    }
}

@Composable
private fun ProofThumb(url: String, path: String?) {
    Box(
        modifier = Modifier
            .size(width = 64.dp, height = 80.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(MMColors.SurfaceInteractive)
            .border(0.5.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        AsyncImage(
            model = rememberSignedImageRequest(url, path),
            contentDescription = "Latest proof photo",
            contentScale = ContentScale.Crop,
            colorFilter = ColorFilter.colorMatrix(ProofThumbnailBrightness),
            modifier = Modifier
                .fillMaxSize()
                .scale(1.08f),
        )
    }
}
