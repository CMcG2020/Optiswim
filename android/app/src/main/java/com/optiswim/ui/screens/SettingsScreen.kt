package com.optiswim.ui.screens

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.optiswim.background.AlertScheduler
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.ui.viewmodel.SettingsViewModel

@Composable
fun SettingsScreen(padding: PaddingValues, viewModel: SettingsViewModel) {
    val level by viewModel.swimmerLevel.collectAsState()
    val dailyAlerts by viewModel.dailyAlerts.collectAsState()
    val useCurrentLocationAlerts by viewModel.useCurrentLocationAlerts.collectAsState()
    val context = LocalContext.current

    var expanded by remember { mutableStateOf(false) }
    var permissionMessage by remember { mutableStateOf<String?>(null) }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            enableAlerts(viewModel, context)
            permissionMessage = null
        } else {
            permissionMessage = "Notifications permission is required for alerts."
        }
    }

    val backgroundLocationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            viewModel.setUseCurrentLocationAlerts(true)
            permissionMessage = null
        } else {
            permissionMessage = "Background location permission was not granted."
        }
    }

    val locationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val granted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (!granted) {
            permissionMessage = "Location permission is required to use current location."
        }
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text(text = "Settings", style = MaterialTheme.typography.titleMedium)
        }

        item {
            SectionHeader(icon = Icons.Filled.Person, title = "Swimmer Profile")
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Box {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { expanded = true },
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(text = level.label)
                            Text(text = "Change")
                        }
                        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            SwimmerLevel.values().forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(option.label) },
                                    onClick = {
                                        viewModel.updateLevel(option)
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            SectionHeader(icon = Icons.Filled.Notifications, title = "Notifications")
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(text = "Daily Alerts")
                        Switch(checked = dailyAlerts, onCheckedChange = { enabled ->
                            if (enabled) {
                                val needsNotificationPermission = Build.VERSION.SDK_INT >= 33 &&
                                    !hasPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                                if (needsNotificationPermission) {
                                    notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                                } else {
                                    enableAlerts(viewModel, context)
                                }
                            } else {
                                viewModel.setDailyAlerts(false)
                                AlertScheduler.cancelAll(context)
                            }
                        })
                    }
                    Text(text = "Safety alerts are managed by background tasks.")
                }
            }
        }

        item {
            SectionHeader(icon = Icons.Filled.LocationOn, title = "Location Alerts")
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(text = "Use Current Location")
                        Switch(
                            checked = useCurrentLocationAlerts,
                            onCheckedChange = { enabled ->
                                if (enabled) {
                                    val hasForeground = hasPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ||
                                        hasPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
                                    if (!hasForeground) {
                                        locationLauncher.launch(
                                            arrayOf(
                                                Manifest.permission.ACCESS_FINE_LOCATION,
                                                Manifest.permission.ACCESS_COARSE_LOCATION
                                            )
                                        )
                                        return@Switch
                                    }
                                    if (Build.VERSION.SDK_INT >= 29 &&
                                        !hasPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                                    ) {
                                        backgroundLocationLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                                    } else {
                                        viewModel.setUseCurrentLocationAlerts(true)
                                        permissionMessage = null
                                    }
                                } else {
                                    viewModel.setUseCurrentLocationAlerts(false)
                                }
                            }
                        )
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = "Enable background location to use current GPS in alerts.")
                }
            }
        }

        if (permissionMessage != null) {
            item {
                Text(text = permissionMessage ?: "", color = MaterialTheme.colorScheme.error)
            }
        }

        item {
            SectionHeader(icon = Icons.Filled.Info, title = "Data Sources")
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Open-Meteo Marine")
                    Text(text = "Open-Meteo Weather")
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(imageVector = icon, contentDescription = null)
        Text(text = title, style = MaterialTheme.typography.titleSmall)
    }
}

private fun enableAlerts(viewModel: SettingsViewModel, context: Context) {
    viewModel.setDailyAlerts(true)
    AlertScheduler.scheduleDaily(context)
    AlertScheduler.scheduleSafety(context)
}

private fun hasPermission(context: Context, permission: String): Boolean {
    return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}
