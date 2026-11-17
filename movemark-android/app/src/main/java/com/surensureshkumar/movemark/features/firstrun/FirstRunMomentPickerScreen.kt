/**
 * @file "What are you documenting?" — the first screen of first run (iOS FirstRunMomentPickerView.swift). Two paths only:
 *       moving in or moving out. Replaces the old "What should we call you?" name step: identity lives in Account.
 * @domain onboarding-auth
 * @status wip
 * @see [[FirstRunFlowScreen.kt]]
 * @tested-by [[FirstRunMomentPickerScreenTest.kt]]
 */
package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSecondaryButton
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy

const val FIRST_RUN_LOADING_RENTALS = "Loading your rentals…"

@Composable
fun FirstRunMomentPickerScreen(
    /** True while rentals are still loading: choosing early could create a second rental for someone who has one. */
    isPreparing: Boolean,
    onSelect: (RentalMoment) -> Unit,
    /** The way out of first run for someone who signed in to the wrong account. */
    onSignOut: (() -> Unit)? = null,
) {
    MMScreen(
        title = MoveMarkGrowthCopy.FIRST_RUN_MOMENT_TITLE,
        lines = listOf(MoveMarkGrowthCopy.FIRST_RUN_MOMENT_SUBTITLE),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            RentalMoment.entries.forEach { moment ->
                FirstRunChoiceCard(
                    title = moment.title,
                    subtitle = moment.blurb,
                    icon = moment.icon,
                    enabled = !isPreparing,
                    tag = "firstRun.moment.${moment.key}",
                    onClick = { onSelect(moment) },
                )
            }
        }
        if (isPreparing) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(start = 4.dp, end = 4.dp, top = 14.dp)
                    .semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(color = MMInk.Secondary, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
                Spacer(Modifier.size(8.dp))
                Text(FIRST_RUN_LOADING_RENTALS, style = mmFont(13f), color = MMInk.Secondary)
            }
        }
        if (onSignOut != null) {
            Spacer(Modifier.height(18.dp))
            MMSecondaryButton(
                title = "Sign out",
                onClick = onSignOut,
                tint = MMInk.Secondary,
                modifier = Modifier.testTag("firstRun.signOut"),
            )
        }
    }
}
