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
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmFont
import androidx.compose.foundation.layout.imePadding
import com.surensureshkumar.movemark.core.design.mmAppearRise
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

    MMScreen(
        title = com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy.FIRST_RUN_SETUP_TITLE,
        lines = listOf(com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy.FIRST_RUN_SETUP_SUBTITLE),
        modifier = Modifier.imePadding(),
    ) {
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "createForm")) {
            MMTextField(title, viewModel::setTitle, "Rental name", onLight = true)
            Spacer(Modifier.height(12.dp))
            MMTextField(address, viewModel::setAddress, "Street address", onLight = true)
            Spacer(Modifier.height(12.dp))
            MMTextField(city, viewModel::setCity, "City", onLight = true)
            Spacer(Modifier.height(12.dp))
            MMTextField(region, viewModel::setRegion, "Province / State", onLight = true)
            Spacer(Modifier.height(20.dp))
            MMGroup {
                MMDateField("Move-in date", moveIn, viewModel::setMoveIn, onLight = true)
                if (askLease) {
                    MMRowDivider()
                    MMDateField("Lease start", leaseStart, viewModel::setLeaseStart, onLight = true)
                    MMRowDivider()
                    MMDateField("Lease end", leaseEnd, viewModel::setLeaseEnd, onLight = true)
                }
            }
            Text(
                "Your move-in date anchors the record: proof captured around it shows the condition you moved into.",
                style = mmFont(13f),
                color = MMInk.Secondary,
                modifier = Modifier.padding(start = 4.dp, top = 8.dp),
            )
            error?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, color = MMInk.Danger, fontSize = 14.sp)
            }
            Spacer(Modifier.height(24.dp))
            MMPrimaryButton(
                title = if (loading) "Creating rental…" else "Create rental",
                onClick = { viewModel.create(askLease, onCreated) },
                isLoading = loading,
                enabled = !loading,
            )
        }
    }
}
