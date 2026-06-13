package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors

enum class MMProofReceiptStripLayout {
    /** PulseFill-style: detail title + saved row inside case card. */
    CaseFile,
    Stacked,
    Horizontal,
}

data class MMProofReceiptStripModel(
    val savedTitle: String = "Saved to your vault",
    val detailTitle: String? = null,
    val detailSubtitle: String? = null,
    val timestampLabel: String? = null,
    val metricsLine: String? = null,
    val statusBadge: String? = null,
    val statusTone: MMProofStatusTone = MMProofStatusTone.Success,
    val cardTitle: String? = null,
    val cardMeta: String? = null,
)

@Composable
fun MMProofReceiptStrip(
    model: MMProofReceiptStripModel,
    layout: MMProofReceiptStripLayout = MMProofReceiptStripLayout.CaseFile,
    modifier: Modifier = Modifier,
    leadingImage: @Composable (() -> Unit)? = null,
) {
    when (layout) {
        MMProofReceiptStripLayout.CaseFile -> CaseFileStrip(model, modifier)
        MMProofReceiptStripLayout.Stacked -> StackedStrip(model, modifier)
        MMProofReceiptStripLayout.Horizontal -> HorizontalStrip(model, modifier, leadingImage)
    }
}

@Composable
private fun CaseFileStrip(model: MMProofReceiptStripModel, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth()) {
        if (model.detailTitle != null || model.detailSubtitle != null) {
            MMProofCaseDetailSection(
                title = model.detailTitle.orEmpty(),
                subtitle = model.detailSubtitle ?: model.metricsLine,
            )
            MMProofCaseDivider()
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.CheckCircle, null, tint = MMColors.Primary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text(model.savedTitle, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = MMColors.TextPrimary)
                model.timestampLabel?.let {
                    Text(it, fontSize = 11.sp, color = MMColors.TextMuted, modifier = Modifier.padding(top = 2.dp))
                }
            }
            model.statusBadge?.let { MMProofStatusBadge(it, model.statusTone) }
        }
    }
}

@Composable
private fun StackedStrip(model: MMProofReceiptStripModel, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(top = 1.dp, bottom = 8.dp),
    ) {
        MMProofCaseDivider()
        Spacer(Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.CheckCircle, null, tint = MMColors.Primary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(model.savedTitle, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = MMColors.TextPrimary)
            Spacer(Modifier.weight(1f))
            model.statusBadge?.let { MMProofStatusBadge(it, model.statusTone) }
        }
        model.timestampLabel?.let {
            Text(it, fontSize = 10.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextSecondary.copy(0.78f), modifier = Modifier.padding(top = 5.dp))
        }
        model.metricsLine?.let {
            Text(it, fontSize = 10.5.sp, color = MMColors.TextSecondary.copy(0.72f), modifier = Modifier.padding(top = 1.dp), maxLines = 1)
        }
    }
}

@Composable
private fun HorizontalStrip(
    model: MMProofReceiptStripModel,
    modifier: Modifier = Modifier,
    leadingImage: @Composable (() -> Unit)?,
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        leadingImage?.invoke()
        if (leadingImage != null) Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            model.cardTitle?.let {
                Text(it, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MMColors.TextPrimary, maxLines = 2)
            }
            model.cardMeta?.let {
                Text(it, fontSize = 12.5.sp, fontWeight = FontWeight.Medium, color = MMColors.TextSecondary.copy(0.8f), maxLines = 2)
            }
        }
    }
}
