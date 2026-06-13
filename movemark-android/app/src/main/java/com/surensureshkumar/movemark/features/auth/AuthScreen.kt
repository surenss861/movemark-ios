package com.surensureshkumar.movemark.features.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.R
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMColors
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun AuthScreen(
    initialMode: AuthMode,
    onDismiss: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    LaunchedEffect(initialMode) {
        viewModel.setMode(initialMode)
    }
    val mode by viewModel.mode.collectAsState()
    val email by viewModel.email.collectAsState()
    val password by viewModel.password.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val message by viewModel.message.collectAsState()
    val isSignUp = mode == AuthMode.SignUp

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp)
                .padding(top = 10.dp, bottom = MMSpacing.TabScrollBottom.dp),
        ) {
            AuthHeaderRow(onDismiss = onDismiss)

            Spacer(Modifier.height(14.dp))

            Text(
                text = if (isSignUp) "Create your proof vault" else "Welcome back.",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = MMColors.TextPrimary,
            )
            Spacer(Modifier.height(5.dp))
            Text(
                text = if (isSignUp) {
                    "Save room photos, lease docs, and reports under one rental."
                } else {
                    "Continue your proof vault."
                },
                fontSize = 15.sp,
                color = MMColors.TextSecondary,
            )

            Spacer(Modifier.height(14.dp))
            AuthProofVaultStrip(mode = mode)

            Spacer(Modifier.height(14.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(MMColors.Card.copy(alpha = 0.88f))
                    .border(0.75.dp, MMColors.CardStroke.copy(alpha = 0.42f), RoundedCornerShape(22.dp))
                    .padding(horizontal = 14.dp, vertical = 14.dp),
            ) {
                MMTextField(email, viewModel::setEmail, "Email", keyboardType = KeyboardType.Email)
                Spacer(Modifier.height(10.dp))
                MMTextField(password, viewModel::setPassword, "Password", isPassword = true)

                message?.let {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        it,
                        color = MMColors.SemanticDanger,
                        fontSize = 13.sp,
                    )
                }

                Spacer(Modifier.height(12.dp))
                MMButton(
                    text = if (isSignUp) "Create private vault" else "Continue proof vault",
                    onClick = viewModel::submit,
                    loading = loading,
                )

                if (!isSignUp) {
                    Spacer(Modifier.height(4.dp))
                    TextButton(
                        onClick = viewModel::resetPassword,
                        modifier = Modifier.align(Alignment.End),
                    ) {
                        Text("Forgot password?", color = MMColors.Primary.copy(alpha = 0.92f), fontSize = 13.sp)
                    }
                }
            }

            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (isSignUp) "Already have an account?" else "New to MoveMark?",
                    color = MMColors.TextSecondary,
                    fontSize = 14.sp,
                )
                TextButton(
                    onClick = {
                        viewModel.setMode(if (isSignUp) AuthMode.SignIn else AuthMode.SignUp)
                    },
                ) {
                    Text(
                        text = if (isSignUp) "Sign in" else "Create private vault",
                        color = MMColors.Primary.copy(alpha = 0.95f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Composable
private fun AuthHeaderRow(onDismiss: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = onDismiss,
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MMColors.Card.copy(alpha = 0.9f))
                .border(0.75.dp, MMColors.CardStroke.copy(alpha = 0.75f), CircleShape),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MMColors.TextPrimary,
                modifier = Modifier.size(18.dp),
            )
        }

        Spacer(Modifier.weight(1f))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(R.drawable.movemark_logo),
                contentDescription = null,
                modifier = Modifier
                    .size(28.dp)
                    .clip(RoundedCornerShape(7.dp)),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "MoveMark",
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = MMColors.TextPrimary,
            )
        }

        Spacer(Modifier.weight(1f))
        Box(Modifier.size(40.dp))
    }
}
