package com.optiswim.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.HorizontalRule
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.optiswim.data.model.HourlyForecast
import com.optiswim.ui.viewmodel.HomeViewModel
import kotlin.math.roundToInt

@Composable
fun HomeScreen(padding: PaddingValues, viewModel: HomeViewModel) {
    val state by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    var hasLocationPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
        )
    }

    val locationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        hasLocationPermission = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    }

    LaunchedEffect(hasLocationPermission) {
        viewModel.refresh(useDeviceLocation = hasLocationPermission)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text(text = "Home", style = MaterialTheme.typography.titleMedium)
                Text(text = state.locationLabel, style = MaterialTheme.typography.bodySmall)
            }
            Button(onClick = { viewModel.refresh(useDeviceLocation = hasLocationPermission) }) {
                Text("Refresh")
            }
        }

        if (!hasLocationPermission) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(text = "Location permission needed", style = MaterialTheme.typography.titleSmall)
                    Text(text = "Enable location to fetch conditions near you.")
                    Button(onClick = {
                        locationLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }) {
                        Text("Enable Location")
                    }
                }
            }
        }

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

            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Current Conditions", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(text = "Wave Height: ${conditions.waveHeight} m")
                    Text(text = "Wind: ${conditions.windSpeed} km/h")
                    Text(text = "Water Temp: ${conditions.seaSurfaceTemperature} C")
                    TideTrendRow(phase = conditions.tidePhase)
                }
            }

            if (state.forecast.isNotEmpty()) {
                ForecastChart(forecast = state.forecast)
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

@Composable
private fun TideTrendRow(phase: String?) {
    val normalized = phase?.lowercase() ?: "mid"
    val (label, icon) = when (normalized) {
        "rising" -> "Rising" to Icons.Filled.ArrowUpward
        "falling" -> "Falling" to Icons.Filled.ArrowDownward
        "high" -> "High" to Icons.Filled.ArrowUpward
        "low" -> "Low" to Icons.Filled.ArrowDownward
        else -> "Mid" to Icons.Filled.HorizontalRule
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(imageVector = icon, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text(text = "Tide: $label")
    }
}

@Composable
private fun ForecastChart(forecast: List<HourlyForecast>) {
    val series = forecast.take(24).map { it.waveHeight }
    val maxValue = series.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    val minValue = series.minOrNull() ?: 0.0

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Next 24h Wave Height", style = MaterialTheme.typography.titleSmall)
            Spacer(modifier = Modifier.height(8.dp))
            Canvas(modifier = Modifier.fillMaxWidth().height(120.dp)) {
                if (series.size < 2) return@Canvas

                val stepX = size.width / (series.size - 1)
                val range = (maxValue - minValue).takeIf { it > 0 } ?: 1.0

                var lastX = 0f
                var lastY = size.height - ((series[0] - minValue) / range * size.height).toFloat()

                for (i in 1 until series.size) {
                    val x = stepX * i
                    val y = size.height - ((series[i] - minValue) / range * size.height).toFloat()
                    drawLine(
                        color = MaterialTheme.colorScheme.primary,
                        start = androidx.compose.ui.geometry.Offset(lastX, lastY),
                        end = androidx.compose.ui.geometry.Offset(x, y),
                        strokeWidth = 4f
                    )
                    lastX = x
                    lastY = y
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "Peak: ${maxValue.roundToInt()} m", style = MaterialTheme.typography.bodySmall)
        }
    }
}
