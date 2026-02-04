package com.optiswim.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.HorizontalRule
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.optiswim.data.model.HourlyForecast
import com.optiswim.ui.viewmodel.HomeViewModel
import java.time.Duration
import java.time.ZoneId
import java.time.format.DateTimeFormatter
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

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            StatusHeader(
                locationLabel = state.locationLabel,
                isLoading = state.isLoading,
                hasError = state.error != null,
                onRefresh = { viewModel.refresh(useDeviceLocation = hasLocationPermission) }
            )
        }

        if (state.selectedLocation != null) {
            item {
                UseCurrentLocationCard(onUseCurrentLocation = { viewModel.clearSelectedLocation() })
            }
        }

        if (!hasLocationPermission) {
            item {
                PermissionCard(onEnable = {
                    locationLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        )
                    )
                })
            }
        }

        if (state.error != null) {
            item {
                ErrorBanner(message = state.error ?: "Error")
            }
        }

        if (state.isLoading) {
            item {
                LoadingCard()
            }
        } else if (state.conditions == null) {
            item {
                EmptyStateCard(onRefresh = { viewModel.refresh(useDeviceLocation = hasLocationPermission) })
            }
        } else {
            val conditions = state.conditions!!
            val score = state.score

            if (score != null) {
                item {
                    ScoreCard(score = score.value, rating = score.rating.label)
                }
            }

            if (state.optimalWindow != null) {
                item {
                    OptimalWindowCard(window = state.optimalWindow)
                }
            }

            item {
                ConditionsGrid(
                    waveHeight = conditions.waveHeight,
                    windSpeed = conditions.windSpeed,
                    waterTemp = conditions.seaSurfaceTemperature,
                    uvIndex = conditions.uvIndex,
                    weatherCode = conditions.weatherCode,
                    tidePhase = conditions.tidePhase
                )
            }

            if (state.forecast.isNotEmpty()) {
                item {
                    ForecastChart(forecast = state.forecast)
                }
            }

            if (score != null && score.warnings.isNotEmpty()) {
                item {
                    WarningsCard(warnings = score.warnings)
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
    val lineColor = MaterialTheme.colorScheme.primary

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
                        color = lineColor,
                        start = androidx.compose.ui.geometry.Offset(lastX, lastY),
                        end = androidx.compose.ui.geometry.Offset(x, y),
                        strokeWidth = 4f
                    )
                    lastX = x
                    lastY = y
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = String.format("Range: %.1fm - %.1fm", minValue, maxValue),
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

@Composable
private fun StatusHeader(
    locationLabel: String,
    isLoading: Boolean,
    hasError: Boolean,
    onRefresh: () -> Unit
) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(text = locationLabel, style = MaterialTheme.typography.titleMedium)
                val statusText = when {
                    isLoading -> "Updating..."
                    hasError -> "Error"
                    else -> "Live"
                }
                Text(text = statusText, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
            }

            IconButton(onClick = onRefresh) {
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.width(20.dp), strokeWidth = 2.dp)
                } else {
                    Icon(imageVector = Icons.Filled.Refresh, contentDescription = "Refresh")
                }
            }
        }
    }
}

@Composable
private fun PermissionCard(onEnable: () -> Unit) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = "Location permission needed", style = MaterialTheme.typography.titleSmall)
            Text(text = "Enable location to fetch conditions near you.")
            Button(onClick = onEnable) {
                Text("Enable Location")
            }
        }
    }
}

@Composable
private fun LoadingCard() {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CircularProgressIndicator()
            Text(text = "Loading conditions...", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun EmptyStateCard(onRefresh: () -> Unit) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(text = "Ready to check conditions?", style = MaterialTheme.typography.titleMedium)
            Text(text = "Tap refresh to get current swimming conditions for your location.")
            Button(onClick = onRefresh) {
                Text("Check Conditions")
            }
        }
    }
}

@Composable
private fun UseCurrentLocationCard(onUseCurrentLocation: () -> Unit) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = "Viewing a saved location", style = MaterialTheme.typography.titleSmall)
            Text(text = "Switch back to your live GPS conditions anytime.")
            Button(onClick = onUseCurrentLocation) {
                Text("Use Current Location")
            }
        }
    }
}

@Composable
private fun ErrorBanner(message: String) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(imageVector = Icons.Filled.Warning, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text(text = message, color = MaterialTheme.colorScheme.onErrorContainer)
        }
    }
}

@Composable
private fun ScoreCard(score: Double, rating: String) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(contentAlignment = Alignment.Center) {
                CircularProgressIndicator(
                    progress = (score / 100f).toFloat(),
                    strokeWidth = 10.dp,
                    modifier = Modifier.size(160.dp)
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = score.roundToInt().toString(), style = MaterialTheme.typography.displaySmall)
                    Text(text = rating, style = MaterialTheme.typography.bodyMedium)
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = when {
                    score >= 85 -> "Perfect conditions for swimming!"
                    score >= 70 -> "Good conditions for swimming"
                    else -> "Check conditions before heading out"
                },
                style = MaterialTheme.typography.titleSmall
            )
        }
    }
}

@Composable
private fun OptimalWindowCard(window: com.optiswim.data.model.TimeWindow) {
    val formatter = DateTimeFormatter.ofPattern("HH:mm")
    val startLocal = window.start.atZone(ZoneId.of("UTC")).withZoneSameInstant(ZoneId.systemDefault())
    val endLocal = window.end.atZone(ZoneId.of("UTC")).withZoneSameInstant(ZoneId.systemDefault())
    val durationHours = Duration.between(window.start, window.end).toHours()

    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(text = "Optimal Swim Window", style = MaterialTheme.typography.titleSmall)
            Text(
                text = "${startLocal.format(formatter)} - ${endLocal.format(formatter)}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(text = "$durationHours hours", style = MaterialTheme.typography.bodySmall)
            Text(text = "Avg Score ${window.averageScore.roundToInt()}", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun ConditionsGrid(
    waveHeight: Double,
    windSpeed: Double,
    waterTemp: Double,
    uvIndex: Double,
    weatherCode: Int,
    tidePhase: String?
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(text = "Current Conditions", style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            ConditionTile(title = "Water Temp", value = "${waterTemp.roundToInt()}°C", modifier = Modifier.weight(1f))
            ConditionTile(title = "Wave Height", value = String.format("%.1fm", waveHeight), modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            ConditionTile(title = "Wind", value = "${windSpeed.roundToInt()} km/h", modifier = Modifier.weight(1f))
            ConditionTile(title = "Weather", value = weatherDescription(weatherCode), modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            ConditionTile(title = "UV Index", value = uvIndex.roundToInt().toString(), modifier = Modifier.weight(1f))
            ConditionTile(title = "Tide", value = tidePhase?.replaceFirstChar { it.uppercase() } ?: "Mid", modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun ConditionTile(title: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = title, style = MaterialTheme.typography.bodySmall)
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun WarningsCard(warnings: List<String>) {
    Card(
        shape = CardDefaults.shape,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(text = "Safety Warnings", style = MaterialTheme.typography.titleSmall)
            warnings.forEach { warning ->
                Text(text = "• $warning", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

private fun weatherDescription(code: Int): String = when (code) {
    0 -> "Clear sky"
    1 -> "Mainly clear"
    2 -> "Partly cloudy"
    3 -> "Overcast"
    45, 48 -> "Fog"
    51, 53, 55 -> "Drizzle"
    61, 63, 65 -> "Rain"
    71, 73, 75 -> "Snow"
    95, 96, 99 -> "Thunderstorm"
    else -> "Mixed"
}
