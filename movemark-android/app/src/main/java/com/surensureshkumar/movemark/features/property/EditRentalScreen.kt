package com.surensureshkumar.movemark.features.property

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMGroup
import com.surensureshkumar.movemark.core.design.MMInk
import com.surensureshkumar.movemark.core.design.MMLightSystemBars
import com.surensureshkumar.movemark.core.design.MMMetrics
import com.surensureshkumar.movemark.core.design.MMNotice
import com.surensureshkumar.movemark.core.design.MMPrimaryButton
import com.surensureshkumar.movemark.core.design.MMRowDivider
import com.surensureshkumar.movemark.core.design.components.MMDateField
import com.surensureshkumar.movemark.core.design.mmFont
import com.surensureshkumar.movemark.core.design.mmIsLargeFont
import com.surensureshkumar.movemark.domain.RentalEditForm
import java.util.UUID
import kotlinx.coroutines.launch

/**
 * Edit rental as a sheet over the caller (iOS `EditPropertyView` in `MMSheetScaffold`): Close, "Edit rental", Save;
 * the form; Save changes. With unsaved edits, a swipe down, a scrim tap, Back or Close asks "Discard changes?"
 * (iOS `mmDiscardChangesGuard`). Each opening gets a fresh form.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditRentalSheet(onDismiss: () -> Unit) {
    // A new key per opening: the view model is scoped to the caller's back-stack entry, so a reused one would
    // reopen with the last session's edits.
    val key = remember { "edit_rental_${UUID.randomUUID()}" }
    val viewModel: EditRentalViewModel = hiltViewModel(key = key)
    var confirmDiscard by remember { mutableStateOf(false) }
    var allowDismiss by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { target ->
            if (target != SheetValue.Hidden || allowDismiss) {
                true
            } else if (viewModel.saving.value) {
                false
            } else if (viewModel.hasChanges) {
                confirmDiscard = true
                false
            } else {
                true
            }
        },
    )
    val scope = rememberCoroutineScope()
    fun dismiss() {
        allowDismiss = true
        scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MMInk.Sheet,
        contentColor = MMInk.Text,
        dragHandle = { BottomSheetDefaults.DragHandle(color = MMInk.Separator) },
    ) {
        EditRentalSheetContent(
            viewModel = viewModel,
            onClose = ::dismiss,
            confirmDiscard = confirmDiscard,
            onConfirmDiscard = { confirmDiscard = it },
        )
    }
}

/**
 * The route-hosted form (`Routes.EditRental`), kept so existing navigation still works: the same sheet content
 * full screen on the light sheet colour. Prefer [EditRentalSheet] over the caller.
 */
@Composable
fun EditRentalScreen(onClose: () -> Unit, viewModel: EditRentalViewModel = hiltViewModel()) {
    var confirmDiscard by remember { mutableStateOf(false) }
    val saving by viewModel.saving.collectAsState()
    MMLightSystemBars(lightStatusBar = true)
    BackHandler(enabled = !saving) { if (viewModel.hasChanges) confirmDiscard = true else onClose() }
    Box(
        Modifier
            .fillMaxSize()
            .background(MMInk.Sheet)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        CompositionLocalProvider(LocalContentColor provides MMInk.Text) {
            EditRentalSheetContent(
                viewModel = viewModel,
                onClose = onClose,
                confirmDiscard = confirmDiscard,
                onConfirmDiscard = { confirmDiscard = it },
            )
        }
    }
}

@Composable
private fun EditRentalSheetContent(
    viewModel: EditRentalViewModel,
    onClose: () -> Unit,
    confirmDiscard: Boolean,
    onConfirmDiscard: (Boolean) -> Unit,
) {
    val form by viewModel.form.collectAsState()
    val saving by viewModel.saving.collectAsState()
    val error by viewModel.error.collectAsState()
    val canSave = !saving && form.canSave(viewModel.initial)
    fun close() = if (viewModel.hasChanges) onConfirmDiscard(true) else onClose()
    fun save() { if (canSave) viewModel.save(onClose) }

    Column(Modifier.fillMaxWidth().imePadding()) {
        EditRentalTopBar(
            closeEnabled = !saving,
            saveEnabled = canSave,
            onClose = ::close,
            onSave = ::save,
        )
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMMetrics.Inset)
                .padding(top = 12.dp, bottom = 32.dp),
        ) {
            CompositionLocalProvider(LocalTextStyle provides LocalTextStyle.current.copy(color = MMInk.Text)) {
                Text(RentalFormSpec.INTRO, style = mmFont(15f), color = MMInk.Secondary)
                EditRentalForm(form, viewModel.initial, viewModel::update)
                RentalFormSpec.notice(error, form, viewModel.initial)?.let {
                    Spacer(Modifier.height(22.dp))
                    MMNotice(message = it)
                }
                Spacer(Modifier.height(26.dp))
                MMPrimaryButton(title = "Save changes", onClick = ::save, isLoading = saving, enabled = canSave)
            }
        }
    }
    if (confirmDiscard) {
        AlertDialog(
            onDismissRequest = { onConfirmDiscard(false) },
            title = { Text(RentalFormSpec.DISCARD_TITLE) },
            confirmButton = {
                TextButton(onClick = { onConfirmDiscard(false); onClose() }) { Text("Discard", color = MMInk.Danger) }
            },
            dismissButton = {
                TextButton(onClick = { onConfirmDiscard(false) }) { Text("Keep editing", color = MMInk.Text) }
            },
        )
    }
}

/** iOS sheet toolbar: Close (cancellation), the inline title, Save (confirmation, semibold). */
@Composable
private fun EditRentalTopBar(closeEnabled: Boolean, saveEnabled: Boolean, onClose: () -> Unit, onSave: () -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 8.dp)) {
        TextButton(onClick = onClose, enabled = closeEnabled, modifier = Modifier.align(Alignment.CenterStart)) {
            Text("Close", style = mmFont(16f), color = MMInk.Text.copy(alpha = if (closeEnabled) 1f else 0.4f))
        }
        Text(
            "Edit rental",
            style = mmFont(17f, FontWeight.SemiBold),
            color = MMInk.Text,
            modifier = Modifier.align(Alignment.Center).semantics { heading() },
        )
        TextButton(onClick = onSave, enabled = saveEnabled, modifier = Modifier.align(Alignment.CenterEnd)) {
            Text("Save", style = mmFont(16f, FontWeight.SemiBold), color = MMInk.Text.copy(alpha = if (saveEnabled) 1f else 0.4f))
        }
    }
}

/**
 * The rental's fields (iOS `RentalFormFields`, Edit: optional details shown): ADDRESS → DATES → ON YOUR RECORD →
 * LANDLORD → DEPOSIT & RENT. Email and amounts carry an inline note once their field is left.
 */
@Composable
internal fun EditRentalForm(form: RentalEditForm, initial: RentalEditForm, onChange: ((RentalEditForm) -> RentalEditForm) -> Unit) {
    val large = mmIsLargeFont()
    var otherChosen by remember { mutableStateOf(RentalFormSpec.countryOption(initial.country) == RentalFormSpec.OTHER) }
    val shownCountry = RentalFormSpec.shownOption(form.country, otherChosen)
    val (address, dates, record, landlord, money) = RentalFormSpec.sections

    Section(address) {
        Field("Street address", "88 Harbour St", form.addressLine1) { v -> onChange { it.copy(addressLine1 = v) } }
        Field("Unit", "Optional", form.unit) { v -> onChange { it.copy(unit = v) } }
        Field("City", "Toronto", form.city) { v -> onChange { it.copy(city = v) } }
        // Side by side, except at large font sizes, where "Postal / ZIP code" would wrap.
        if (large) {
            RegionField(form, onChange, Modifier)
            PostalField(form, onChange, Modifier)
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
                RegionField(form, onChange, Modifier.weight(1f))
                PostalField(form, onChange, Modifier.weight(1f))
            }
        }
        CountryPicker(shownCountry) { option ->
            otherChosen = option == RentalFormSpec.OTHER
            onChange { RentalFormSpec.choose(option, it) }
        }
        if (shownCountry == RentalFormSpec.OTHER) {
            Field(
                "Country code",
                "e.g. FR, DE",
                form.country,
                capitalization = KeyboardCapitalization.Characters,
                imeAction = ImeAction.Done,
            ) { v -> onChange { it.copy(country = v) } }
        }
    }
    Section(dates) {
        MMGroup(footer = RentalFormSpec.DATES_FOOTER) {
            MMDateField("Move-in date", form.moveInDate, { v -> onChange { it.copy(moveInDate = v) } }, onLight = true)
            MMRowDivider()
            MMDateField("Lease start", form.leaseStart, { v -> onChange { it.copy(leaseStart = v) } }, onLight = true)
            MMRowDivider()
            MMDateField("Lease end", form.leaseEnd, { v -> onChange { it.copy(leaseEnd = v) } }, onLight = true)
        }
    }
    Section(record) {
        Field("Rental name", "Leave blank to use the street address", form.name) { v -> onChange { it.copy(name = v) } }
    }
    Section(landlord) {
        Field("Name", "Landlord or property manager", form.landlordName) { v -> onChange { it.copy(landlordName = v) } }
        Field(
            "Email",
            "Optional",
            form.landlordEmail,
            keyboard = KeyboardType.Email,
            capitalization = KeyboardCapitalization.None,
            issue = RentalFormSpec.emailIssue(form),
        ) { v -> onChange { it.copy(landlordEmail = v) } }
        Field("Phone", "Optional", form.landlordPhone, keyboard = KeyboardType.Phone) { v -> onChange { it.copy(landlordPhone = v) } }
    }
    Section(money) {
        Field(
            "Deposit amount",
            "e.g. 1500",
            form.depositAmount,
            keyboard = KeyboardType.Decimal,
            issue = RentalFormSpec.depositIssue(form),
        ) { v -> onChange { it.copy(depositAmount = v) } }
        Field(
            "Monthly rent",
            "Optional",
            form.rentAmount,
            keyboard = KeyboardType.Decimal,
            imeAction = ImeAction.Done,
            issue = RentalFormSpec.rentIssue(form),
        ) { v -> onChange { it.copy(rentAmount = v) } }
    }
}

@Composable
private fun RegionField(form: RentalEditForm, onChange: ((RentalEditForm) -> RentalEditForm) -> Unit, modifier: Modifier) {
    Field("Province / state", "ON", form.region, capitalization = KeyboardCapitalization.Characters, modifier = modifier) { v ->
        onChange { it.copy(region = v) }
    }
}

@Composable
private fun PostalField(form: RentalEditForm, onChange: ((RentalEditForm) -> RentalEditForm) -> Unit, modifier: Modifier) {
    Field("Postal / ZIP code", "M5J 2N8", form.postalCode, capitalization = KeyboardCapitalization.Characters, modifier = modifier) { v ->
        onChange { it.copy(postalCode = v) }
    }
}

/** iOS: a grouped "Country" row with a menu picker of the fixed codes and Other. */
@Composable
private fun CountryPicker(selected: String, onSelect: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    MMGroup {
        Box {
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = MMMetrics.RowHeight)
                    .padding(start = 16.dp, end = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Country", style = mmFont(16f), color = MMInk.Text, modifier = Modifier.weight(1f))
                TextButton(
                    onClick = { open = true },
                    modifier = Modifier.semantics { contentDescription = "Country, $selected" },
                ) {
                    Text(selected, style = mmFont(16f), color = MMInk.Text)
                    Icon(Icons.Filled.ArrowDropDown, contentDescription = null, tint = MMInk.Secondary, modifier = Modifier.size(20.dp))
                }
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }, modifier = Modifier.align(Alignment.CenterEnd)) {
                RentalFormSpec.countryOptions.forEach { option ->
                    DropdownMenuItem(text = { Text(option) }, onClick = { open = false; onSelect(option) })
                }
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.padding(top = 26.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            title.uppercase(),
            style = mmFont(12f, FontWeight.Medium, tracking = 0.3f),
            color = MMInk.Secondary,
            modifier = Modifier.padding(start = 4.dp).semantics { heading() },
        )
        content()
    }
}

/**
 * iOS `MMField`: the label above (13 medium, secondary), a white rounded field with a hairline, a placeholder;
 * [issue] shows in red under the field once it isn't focused.
 */
@Composable
private fun Field(
    title: String,
    placeholder: String,
    value: String,
    modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.Words,
    imeAction: ImeAction = ImeAction.Next,
    issue: String? = null,
    onChange: (String) -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // The field itself carries the label for TalkBack, so the visual label isn't read twice.
        Text(title, style = mmFont(13f, FontWeight.Medium), color = MMInk.Secondary, modifier = Modifier.clearAndSetSemantics {})
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            placeholder = { Text(placeholder, style = mmFont(16f), color = MMInk.Secondary.copy(alpha = 0.7f)) },
            textStyle = mmFont(16f).copy(color = MMInk.Text),
            singleLine = true,
            isError = issue != null && !focused,
            shape = RoundedCornerShape(12.dp),
            keyboardOptions = KeyboardOptions(capitalization = capitalization, keyboardType = keyboard, autoCorrectEnabled = false, imeAction = imeAction),
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = title },
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = MMInk.Text,
                unfocusedTextColor = MMInk.Text,
                errorTextColor = MMInk.Text,
                focusedBorderColor = MMInk.Text,
                unfocusedBorderColor = MMInk.CardStroke,
                errorBorderColor = MMInk.Danger,
                cursorColor = MMInk.Text,
                errorCursorColor = MMInk.Text,
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White,
                errorContainerColor = Color.White,
            ),
        )
        if (issue != null && !focused) {
            Text(issue, style = mmFont(12.5f), color = MMInk.Danger, modifier = Modifier.padding(start = 4.dp))
        }
    }
}
