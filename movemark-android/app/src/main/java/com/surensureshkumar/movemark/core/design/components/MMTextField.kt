package com.surensureshkumar.movemark.core.design.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.Color
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMInk

@Composable
fun MMTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    /** On the 1.4 light sheet (MMScreen): ink text on the field fill, as the iOS forms. */
    onLight: Boolean = false,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = if (onLight) OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MMInk.Text,
            unfocusedBorderColor = MMInk.Separator,
            focusedTextColor = MMInk.Text,
            unfocusedTextColor = MMInk.Text,
            focusedLabelColor = MMInk.Secondary,
            unfocusedLabelColor = MMInk.Secondary,
            cursorColor = MMInk.Text,
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White,
        ) else OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MMColors.Primary,
            unfocusedBorderColor = MMColors.CardStroke,
            focusedTextColor = MMColors.TextPrimary,
            unfocusedTextColor = MMColors.TextPrimary,
            focusedLabelColor = MMColors.TextSecondary,
            unfocusedLabelColor = MMColors.TextMuted,
            cursorColor = MMColors.Primary,
            focusedContainerColor = MMColors.FieldFill,
            unfocusedContainerColor = MMColors.FieldFill,
        ),
        singleLine = true,
    )
}
