package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.components.MMProofCaseAccentRail
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCard
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCardStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCaseHeader
import com.surensureshkumar.movemark.core.design.components.MMProofIssueTag
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPane
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPaneSize
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStrip
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStripLayout
import com.surensureshkumar.movemark.core.design.components.MMProofReceiptStripModel
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

private val CardCorner = 24.dp

private val WelcomeIssueTags = listOf(
    MMProofIssueTag("prior", "Already there", priorDamage = true, leadingInset = 4.dp),
    MMProofIssueTag("paint", "Chipped paint", leadingInset = 22.dp),
    MMProofIssueTag("stain", "Water stain", leadingInset = 36.dp),
)

@Composable
fun WelcomeDepositCaseFile(
    heroHeight: Dp,
    cardVisible: Boolean,
    tagsVisible: Boolean,
    reduceMotion: Boolean,
    modifier: Modifier = Modifier,
) {
    val cardAlpha by animateFloatAsState(
        targetValue = if (cardVisible) 1f else 0f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardAlpha",
    )
    val cardOffsetY by animateFloatAsState(
        targetValue = if (cardVisible) 0f else 14f,
        animationSpec = MMMotion.welcomeEnterSpec(reduceMotion),
        label = "welcomeCardOffset",
    )

    // Metadata + photo + detail + receipt
    val metadataAndReceiptHeight = 118.dp
    val photoHeight = (heroHeight - metadataAndReceiptHeight).coerceAtLeast(140.dp)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heroHeight)
            .alpha(cardAlpha)
            .offset(y = cardOffsetY.dp),
    ) {
        MMProofCaseCard(
            style = MMProofCaseCardStyle.Marketing,
            cornerRadius = CardCorner,
            header = MMProofCaseHeader(
                eyebrow = "Move-in proof",
                statusLabel = "Report ready",
                statusTone = MMProofStatusTone.Success,
                accentRail = MMProofCaseAccentRail.Saved,
            ),
            footer = {
                MMProofReceiptStrip(
                    model = MMProofReceiptStripModel(
                        detailTitle = "Kitchen",
                        detailSubtitle = "12 photos · 3 issues",
                        savedTitle = "Saved to your vault",
                        timestampLabel = "Move-in · Apr 14 · 5:42 PM",
                        statusBadge = "Ready",
                        statusTone = MMProofStatusTone.Success,
                    ),
                    layout = MMProofReceiptStripLayout.CaseFile,
                )
            },
        ) {
            MMProofPhotoPane(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(photoHeight),
                size = MMProofPhotoPaneSize.Large,
                drawableResId = R.drawable.welcome_kitchen_main,
                roomName = "Kitchen",
                phaseLabel = "Move-in proof",
                phaseBadge = "Before move-in",
                issueTags = WelcomeIssueTags,
                tagsVisible = tagsVisible,
                showScanCorners = true,
                reduceMotion = reduceMotion,
            )
        }
    }
}
