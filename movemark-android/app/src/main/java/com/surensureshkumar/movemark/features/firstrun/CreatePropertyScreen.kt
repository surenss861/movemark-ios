package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMProofSectionHeader
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.core.design.components.MMDateField

@Composable
fun CreatePropertyScreen(
    onCreated: () -> Unit,
    /** Adding a rental asks for the lease too; first-run setup asks only for the move-in date (as on iOS). */
    askLease: Boolean = false,
    viewModel: CreatePropertyViewModel = hiltViewModel(),
) {
    val title by viewModel.title.collectAsState()
    val address by viewModel.address.collectAsState()
    val city by viewModel.city.collectAsState()
    val region by viewModel.region.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    val moveIn by viewModel.moveIn.collectAsState()
    val leaseStart by viewModel.leaseStart.collectAsState()
    val leaseEnd by viewModel.leaseEnd.collectAsState()
    val reduceMotion = MMMotion.rememberReduceMotion()
    var appeared by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) appeared = true
    }

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 24.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            MMProofSectionHeader(
                title = com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy.FIRST_RUN_SETUP_TITLE,
                subtitle = com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy.FIRST_RUN_SETUP_SUBTITLE,
                modifier = Modifier.mmAppearRise(appeared, reduceMotion, label = "createHeader"),
            )
            Spacer(Modifier.height(20.dp))
            Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "createForm")) {
                MMTextField(title, viewModel::setTitle, "Rental name")
                Spacer(Modifier.height(12.dp))
                MMTextField(address, viewModel::setAddress, "Street address")
                Spacer(Modifier.height(12.dp))
                MMTextField(city, viewModel::setCity, "City")
                Spacer(Modifier.height(12.dp))
                MMTextField(region, viewModel::setRegion, "Province / State")
                Spacer(Modifier.height(20.dp))
                MMDateField("Move-in date", moveIn, viewModel::setMoveIn)
                if (askLease) {
                    MMDateField("Lease start", leaseStart, viewModel::setLeaseStart)
                    MMDateField("Lease end", leaseEnd, viewModel::setLeaseEnd)
                }
                Text(
                    "Your move-in date anchors the record: proof captured around it shows the condition you moved into.",
                    fontSize = 13.sp,
                    color = MMColors.TextSecondary,
                    modifier = Modifier.padding(start = 4.dp, top = 6.dp),
                )
                error?.let {
                    Spacer(Modifier.height(12.dp))
                    Text(it, color = MMColors.SemanticDanger, fontSize = 14.sp)
                }
                Spacer(Modifier.height(24.dp))
                MMButton(
                    text = if (loading) "Creating rental…" else "Create rental",
                    onClick = { viewModel.create(askLease, onCreated) },
                    loading = loading,
                    enabled = !loading,
                )
            }
        }
    }
}
