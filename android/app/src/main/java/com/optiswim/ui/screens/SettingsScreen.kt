package com.optiswim.ui.screens

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
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.background.AlertScheduler
import com.optiswim.ui.viewmodel.SettingsViewModel

@Composable
fun SettingsScreen(padding: PaddingValues, viewModel: SettingsViewModel) {
    val level by viewModel.swimmerLevel.collectAsState()
    val dailyAlerts by viewModel.dailyAlerts.collectAsState()
    val context = LocalContext.current

    var expanded by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = "Settings", style = MaterialTheme.typography.titleMedium)

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = "Swimmer Profile", style = MaterialTheme.typography.titleSmall)
                Spacer(modifier = Modifier.height(8.dp))
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

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(text = "Daily Alerts")
                    Switch(
                        checked = dailyAlerts,
                        onCheckedChange = { enabled ->
                            viewModel.setDailyAlerts(enabled)
                            if (enabled) {
                                AlertScheduler.scheduleDaily(context)
                                AlertScheduler.scheduleSafety(context)
                            } else {
                                AlertScheduler.cancelAll(context)
                            }
                        }
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = "Safety alerts are managed by background tasks.")
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = "Data Sources", style = MaterialTheme.typography.titleSmall)
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = "Open-Meteo Marine")
                Text(text = "Open-Meteo Weather")
            }
        }
    }
}
