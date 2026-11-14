package com.surensureshkumar.movemark.features.property

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.ui.graphics.Color
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.MMScreen
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMDateField
import com.surensureshkumar.movemark.domain.RentalEditForm

/** Edit rental: a plain utility form (the same fields as setup), Save (iOS `EditPropertyView`). */
@Composable
fun EditRentalScreen(onClose: () -> Unit, viewModel: EditRentalViewModel = hiltViewModel()) {
    val form by viewModel.form.collectAsState()
    val saving by viewModel.saving.collectAsState()
    val error by viewModel.error.collectAsState()
    var confirmDiscard by remember { mutableStateOf(false) }
    fun close() = if (viewModel.hasChanges) confirmDiscard = true else onClose()
    BackHandler(enabled = !saving) { close() }

    // 1.4 grammar (iOS EditPropertyView inside MMScreen): header with back, the form on the light sheet, one action.
    MMScreen(title = "Edit rental", onBack = { if (!saving) close() }, modifier = Modifier.imePadding()) {
        EditRentalForm(form, viewModel.initial, viewModel::update)
        (error ?: form.validationError ?: form.leaseError(viewModel.initial) ?: form.detailsIssue(viewModel.initial))?.let {
            Spacer(Modifier.height(16.dp))
            Text(it, color = if (error != null) MMInk.Danger else MMInk.Secondary, fontSize = 14.sp)
        }
        Spacer(Modifier.height(22.dp))
        MMPrimaryButton(
            title = "Save changes",
            onClick = { viewModel.save(onClose) },
            isLoading = saving,
            enabled = !saving && form.canSave(viewModel.initial),
        )
    }
    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { confirmDiscard = false },
            title = { Text("Discard your changes?") },
            confirmButton = {
                TextButton(onClick = { confirmDiscard = false; onClose() }) { Text("Discard", color = MMInk.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDiscard = false }) { Text("Keep editing", color = MMInk.Text) }
            },
        )
    }
}

@Composable
internal fun EditRentalForm(form: RentalEditForm, initial: RentalEditForm, onChange: ((RentalEditForm) -> RentalEditForm) -> Unit) {
    Section("Rental") {
        Field("Name (optional)", form.name, "Shown instead of the address") { v -> onChange { it.copy(name = v) } }
        Field("Street address", form.addressLine1) { v -> onChange { it.copy(addressLine1 = v) } }
        Field("Unit (optional)", form.unit) { v -> onChange { it.copy(unit = v) } }
        Field("City", form.city) { v -> onChange { it.copy(city = v) } }
        Field("Province or state", form.region) { v -> onChange { it.copy(region = v) } }
        Field("Postal code", form.postalCode, capitalization = KeyboardCapitalization.Characters) { v -> onChange { it.copy(postalCode = v) } }
        Field("Country", form.country, capitalization = KeyboardCapitalization.Characters) { v -> onChange { it.copy(country = v) } }
    }
    Section("Dates") {
        MMGroup {
            MMDateField("Move-in date", form.moveInDate, { v -> onChange { it.copy(moveInDate = v) } }, onLight = true)
            MMRowDivider()
            MMDateField("Lease start", form.leaseStart, { v -> onChange { it.copy(leaseStart = v) } }, onLight = true)
            MMRowDivider()
            MMDateField("Lease end", form.leaseEnd, { v -> onChange { it.copy(leaseEnd = v) } }, onLight = true)
        }
        Text(
            "Your move-in date anchors the record: proof captured around it shows the condition you moved into.",
            fontSize = 13.sp,
            color = MMInk.Secondary,
            modifier = Modifier.padding(start = 4.dp, top = 6.dp),
        )
    }
    Section("Landlord") {
        Field("Name (optional)", form.landlordName) { v -> onChange { it.copy(landlordName = v) } }
        Field("Email (optional)", form.landlordEmail, keyboard = KeyboardType.Email, capitalization = KeyboardCapitalization.None) { v -> onChange { it.copy(landlordEmail = v) } }
        Field("Phone (optional)", form.landlordPhone, keyboard = KeyboardType.Phone) { v -> onChange { it.copy(landlordPhone = v) } }
    }
    Section("Money") {
        Field("Deposit (optional)", form.depositAmount, keyboard = KeyboardType.Decimal) { v -> onChange { it.copy(depositAmount = v) } }
        Field("Monthly rent (optional)", form.rentAmount, keyboard = KeyboardType.Decimal) { v -> onChange { it.copy(rentAmount = v) } }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Spacer(Modifier.height(22.dp))
    Text(
        title.uppercase(),
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.3.sp,
        color = MMInk.Secondary,
        modifier = Modifier.padding(start = 4.dp, bottom = 12.dp).semantics { heading() },
    )
    content()
}

@Composable
private fun Field(
    label: String,
    value: String,
    supporting: String? = null,
    keyboard: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Words,
    onChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        supportingText = supporting?.let { { Text(it) } },
        keyboardOptions = KeyboardOptions(capitalization = capitalization, keyboardType = keyboard, imeAction = ImeAction.Next),
        modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MMInk.Text,
            unfocusedTextColor = MMInk.Text,
            focusedBorderColor = MMInk.Text,
            unfocusedBorderColor = MMInk.Separator,
            focusedLabelColor = MMInk.Secondary,
            unfocusedLabelColor = MMInk.Secondary,
            cursorColor = MMInk.Text,
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White,
            focusedSupportingTextColor = MMInk.Secondary,
            unfocusedSupportingTextColor = MMInk.Secondary,
        ),
    )
}
