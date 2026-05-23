package com.surensureshkumar.movemark.features.welcome

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.components.MMProofCaseAccentRail
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCard
import com.surensureshkumar.movemark.core.design.components.MMProofCaseCardStyle
import com.surensureshkumar.movemark.core.design.components.MMProofCaseDetailSection
import com.surensureshkumar.movemark.core.design.components.MMProofCaseDivider
import com.surensureshkumar.movemark.core.design.components.MMProofCaseHeader
import com.surensureshkumar.movemark.core.design.components.MMProofCaseReceiptRow
import com.surensureshkumar.movemark.core.design.components.MMProofIssueTag
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoOverlayStyle
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPane
import com.surensureshkumar.movemark.core.design.components.MMProofPhotoPaneSize
import com.surensureshkumar.movemark.core.design.components.MMProofStatusTone

private val CardCorner = 28.dp
private val EmbeddedPhotoHeight = 148.dp

private val WelcomeIssueTags = listOf(
    MMProofIssueTag("prior", "Already there", priorDamage = true, leadingInset = 4.dp),
    MMProofIssueTag("paint", "Chipped paint", leadingInset = 22.dp),
    MMProofIssueTag("stain", "Water stain", leadingInset = 36.dp),
)

/**
 * Welcome demo — PulseFill case-file structure with embedded proof photo pane.
 * Photo is evidence inside the file; room title and metrics live below the image.
 */
@Composable
fun WelcomeDepositCaseFile(
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

    Box(
        modifier = modifier
            .fillMaxWidth()
            .alpha(cardAlpha)
            .offset(y = cardOffsetY.dp),
    ) {
        MMProofCaseCard(
            style = MMProofCaseCardStyle.Standard,
            cornerRadius = CardCorner,
            header = MMProofCaseHeader(
                eyebrow = "Move-in proof",
                statusLabel = "Report ready",
                statusTone = MMProofStatusTone.Success,
                accentRail = MMProofCaseAccentRail.Saved,
            ),
        ) {
            MMProofPhotoPane(
                modifier = Modifier
                    .padding(horizontal = 12.dp, vertical = 10.dp)
                    .fillMaxWidth()
                    .height(EmbeddedPhotoHeight),
                size = MMProofPhotoPaneSize.Large,
                drawableResId = R.drawable.welcome_kitchen_main,
                issueTags = WelcomeIssueTags,
                tagsVisible = tagsVisible,
                overlayStyle = MMProofPhotoOverlayStyle.TagsOnly,
                showScanCorners = true,
                reduceMotion = reduceMotion,
            )
            MMProofCaseDivider()
            MMProofCaseDetailSection(
                title = "Kitchen",
                subtitle = "12 photos · 3 issues",
            )
            MMProofCaseDivider()
            MMProofCaseReceiptRow(
                savedTitle = "Saved to your vault",
                timestampLabel = "Move-in · Apr 14 · 5:42 PM",
                statusBadge = "Ready",
                statusTone = MMProofStatusTone.Success,
            )
        }
    }
}
