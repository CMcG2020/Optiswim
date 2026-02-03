package com.optiswim.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.optiswim.ui.viewmodel.HomeViewModel

@Composable
fun HomeScreen(padding: PaddingValues, viewModel: HomeViewModel) {
    val state by viewModel.uiState.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (state.isLoading) {
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                CircularProgressIndicator()
                Spacer(modifier = Modifier.height(12.dp))
                Text(text = "Loading conditions...")
            }
        } else if (state.error != null) {
            Text(text = state.error ?: "Error", color = MaterialTheme.colorScheme.error)
        } else if (state.conditions != null) {
            val conditions = state.conditions
            val score = state.score

            val tideLabel = conditions.tidePhase ?: "mid"

            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Current Conditions", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(text = "Wave Height: ${conditions.waveHeight} m")
                    Text(text = "Wind: ${conditions.windSpeed} km/h")
                    Text(text = "Water Temp: ${conditions.seaSurfaceTemperature} C")
                    Text(text = "Tide: $tideLabel")
                    if (state.forecast.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(text = "Forecast hours: ${state.forecast.size}")
                    }
                }
            }

            if (score != null) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Swim Score", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(text = "${score.value.toInt()}/100 - ${score.rating.label}")
                        if (score.warnings.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(text = "Warnings", style = MaterialTheme.typography.titleSmall)
                            score.warnings.forEach { warning ->
                                Text(text = "- $warning")
                            }
                        }
                    }
                }
            }
        }
    }
}
