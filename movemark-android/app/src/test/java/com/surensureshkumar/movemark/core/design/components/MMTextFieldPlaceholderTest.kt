package com.surensureshkumar.movemark.core.design.components

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** iOS `MMField(placeholder:)`: the placeholder is there while the field is empty and gone once it holds text. */
@RunWith(AndroidJUnit4::class)
class MMTextFieldPlaceholderTest {
    @get:Rule val compose = createComposeRule()

    private fun setField(placeholder: String?, initial: String = "") {
        compose.setContent {
            var value by remember { mutableStateOf(initial) }
            MMTextField(
                value = value,
                onValueChange = { value = it },
                label = "Email",
                modifier = Modifier.testTag("field"),
                onLight = true,
                placeholder = placeholder,
            )
        }
    }

    @Test
    fun emptyFieldShowsThePlaceholder() {
        setField("you@example.com")
        // Focused, so the floating label has moved up and the placeholder is fully visible (Material behaviour).
        compose.onNodeWithTag("field").performClick()
        compose.onNodeWithText("you@example.com", useUnmergedTree = true).assertExists()
    }

    @Test
    fun typingHidesThePlaceholder() {
        setField("you@example.com")
        compose.onNodeWithTag("field").performTextInput("a@b.co")
        compose.onNodeWithText("you@example.com", useUnmergedTree = true).assertDoesNotExist()
    }

    @Test
    fun aFilledFieldHasNoPlaceholder() {
        setField("Toronto", initial = "Halifax")
        compose.onNodeWithText("Toronto", useUnmergedTree = true).assertDoesNotExist()
    }

    @Test
    fun withoutAPlaceholderNothingExtraIsShown() {
        setField(null)
        compose.onNodeWithText("you@example.com", useUnmergedTree = true).assertDoesNotExist()
        compose.onNodeWithText("Email", useUnmergedTree = true).assertExists()
    }
}
