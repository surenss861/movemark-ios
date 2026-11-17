package com.surensureshkumar.movemark.features.firstrun

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMMotion
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.mmAppearRise
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.core.design.components.MMDateField
import com.surensureshkumar.movemark.core.design.components.MMTextField
import com.surensureshkumar.movemark.core.growth.MoveMarkGrowthCopy

@Composable
fun CreatePropertyScreen(
    onCreated: () -> Unit,
    /** Adding a rental asks for the lease too; first-run setup asks only for the move-in date (as on iOS). */
    askLease: Boolean = false,
    /** First run: back to the moment picker (iOS FirstRunBackButton). */
    onBack: (() -> Unit)? = null,
    viewModel: CreatePropertyViewModel = hiltViewModel(),
) {
    val title by viewModel.title.collectAsState()
    val address by viewModel.address.collectAsState()
    val unit by viewModel.unit.collectAsState()
    val city by viewModel.city.collectAsState()
    val region by viewModel.region.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()
    val moveIn by viewModel.moveIn.collectAsState()
    val leaseStart by viewModel.leaseStart.collectAsState()
    val leaseEnd by viewModel.leaseEnd.collectAsState()
    val reduceMotion = MMMotion.rememberReduceMotion()
    var appeared by remember { mutableStateOf(reduceMotion) }
    val focus = LocalFocusManager.current

    LaunchedEffect(reduceMotion) {
        if (!reduceMotion) appeared = true
    }

    MMScreen(
        title = MoveMarkGrowthCopy.FIRST_RUN_SETUP_TITLE,
        lines = listOf(MoveMarkGrowthCopy.FIRST_RUN_SETUP_SUBTITLE),
        onBack = if (loading) null else onBack,
        modifier = Modifier.imePadding(),
    ) {
        Column(Modifier.mmAppearRise(appeared, reduceMotion, label = "createForm")) {
            if (askLease) {
                // Add rental (iOS NewPropertyView) keeps its nickname field.
                MMTextField(title, viewModel::setTitle, "Rental name", onLight = true)
                Spacer(Modifier.height(14.dp))
                MMTextField(address, viewModel::setAddress, "Street address", onLight = true)
                Spacer(Modifier.height(14.dp))
                MMTextField(unit, viewModel::setUnit, "Unit", onLight = true)
                Spacer(Modifier.height(14.dp))
                MMTextField(city, viewModel::setCity, "City", onLight = true)
                Spacer(Modifier.height(14.dp))
                MMTextField(region, viewModel::setRegion, "Province / State", onLight = true)
            } else {
                // iOS FirstRunPropertySetupView: street, unit, then city and province on one row (as on an envelope)
                // until large text needs the width. No rental name: the title comes from the address.
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    FirstRunField(
                        title = "Street address",
                        placeholder = "88 Harbour St",
                        value = address,
                        onValueChange = viewModel::setAddress,
                        tag = "setup.street",
                    )
                    FirstRunField(
                        title = "Unit",
                        placeholder = "Optional",
                        value = unit,
                        onValueChange = viewModel::setUnit,
                        capitalization = KeyboardCapitalization.Characters,
                        tag = "setup.unit",
                    )
                    if (mmIsLargeFont()) {
                        CityField(city, viewModel::setCity)
                        ProvinceField(region, viewModel::setRegion) { focus.clearFocus() }
                    } else {
                        Row(verticalAlignment = Alignment.Top) {
                            CityField(city, viewModel::setCity, Modifier.weight(1f))
                            Spacer(Modifier.width(12.dp))
                            ProvinceField(region, viewModel::setRegion, Modifier.width(112.dp)) { focus.clearFocus() }
                        }
                    }
                }
            }
            Spacer(Modifier.height(22.dp))
            MMGroup {
                MMDateField("Move-in date", moveIn, viewModel::setMoveIn, onLight = true)
                if (askLease) {
                    MMRowDivider()
                    MMDateField("Lease start", leaseStart, viewModel::setLeaseStart, onLight = true)
                    MMRowDivider()
                    MMDateField("Lease end", leaseEnd, viewModel::setLeaseEnd, onLight = true)
                }
            }
            error?.let {
                Spacer(Modifier.height(22.dp))
                MMNotice(it)
            }
            Spacer(Modifier.height(26.dp))
            // iOS keeps the title and shows the spinner; the CTA waits for a street address.
            MMPrimaryButton(
                title = MoveMarkGrowthCopy.FIRST_RUN_SETUP_CTA,
                onClick = {
                    focus.clearFocus()
                    viewModel.create(askLease, onCreated)
                },
                isLoading = loading,
                enabled = !loading && address.isNotBlank(),
                modifier = Modifier.testTag("setup.create"),
            )
        }
    }
}

@Composable
private fun CityField(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier) {
    FirstRunField(
        title = "City",
        placeholder = "Toronto",
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        tag = "setup.city",
    )
}

@Composable
private fun ProvinceField(value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, onDone: () -> Unit) {
    FirstRunField(
        title = "Province",
        placeholder = "ON",
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        capitalization = KeyboardCapitalization.Characters,
        imeAction = ImeAction.Done,
        onImeAction = onDone,
        tag = "setup.province",
    )
}
