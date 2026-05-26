package com.surensureshkumar.movemark.features.welcome

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy

@Composable
fun WelcomeOnboardingStory(modifier: Modifier = Modifier) {
    val steps = MoveMarkGrowthCopy.ONBOARDING_STORY_STEPS
    val pagerState = rememberPagerState(pageCount = { steps.size })

    Column(modifier = modifier) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(108.dp),
        ) { page ->
            val step = steps[page]
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    step.title,
                    color = MMColors.TextPrimary,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                )
                Text(
                    step.body,
                    color = MMColors.TextSecondary,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                )
            }
        }
        Row(
            Modifier.padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            repeat(steps.size) { index ->
                val selected = pagerState.currentPage == index
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .height(6.dp)
                        .width(if (selected) 18.dp else 6.dp)
                        .clip(RoundedCornerShape(50))
                        .background(
                            if (selected) MMColors.Primary.copy(alpha = 0.9f)
                            else MMColors.TextSecondary.copy(alpha = 0.28f),
                        ),
                )
            }
        }
    }
}
