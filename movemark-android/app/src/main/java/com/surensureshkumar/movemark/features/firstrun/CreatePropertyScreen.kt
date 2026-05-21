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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.surensureshkumar.movemark.core.design.MMBackground
import com.surensureshkumar.movemark.core.design.MMSpacing
import com.surensureshkumar.movemark.core.design.components.MMButton
import com.surensureshkumar.movemark.core.design.components.MMTextField

@Composable
fun CreatePropertyScreen(
    onCreated: () -> Unit,
    viewModel: CreatePropertyViewModel = hiltViewModel(),
) {
    val title by viewModel.title.collectAsState()
    val address by viewModel.address.collectAsState()
    val city by viewModel.city.collectAsState()
    val region by viewModel.region.collectAsState()
    val loading by viewModel.loading.collectAsState()
    val error by viewModel.error.collectAsState()

    MMBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MMSpacing.ScreenHorizontal.dp, vertical = 32.dp),
        ) {
            Text("Create your proof vault", style = androidx.compose.material3.MaterialTheme.typography.headlineLarge)
            Text(
                "Add your rental so you can start room proof.",
                style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
            )
            Spacer(Modifier.height(20.dp))
            MMTextField(title, viewModel::setTitle, "Rental name")
            Spacer(Modifier.height(12.dp))
            MMTextField(address, viewModel::setAddress, "Street address")
            Spacer(Modifier.height(12.dp))
            MMTextField(city, viewModel::setCity, "City")
            Spacer(Modifier.height(12.dp))
            MMTextField(region, viewModel::setRegion, "Province / State")
            error?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, color = com.surensureshkumar.movemark.core.design.MMColors.SemanticDanger)
            }
            Spacer(Modifier.height(24.dp))
            MMButton(
                text = "Create rental",
                onClick = { viewModel.create(onCreated) },
                loading = loading,
            )
        }
    }
}
