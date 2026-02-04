package com.optiswim.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import com.optiswim.data.model.SwimLocationEntity
import com.optiswim.ui.viewmodel.LocationsViewModel

@Composable
fun LocationsScreen(
    padding: PaddingValues,
    viewModel: LocationsViewModel,
    onSelectLocation: (SwimLocationEntity) -> Unit,
    onUseCurrentLocation: () -> Unit
) {
    val locations by viewModel.locations.collectAsState()
    var name by remember { mutableStateOf("") }
    var lat by remember { mutableStateOf("") }
    var lon by remember { mutableStateOf("") }
    var search by remember { mutableStateOf("") }
    var showAdd by remember { mutableStateOf(false) }

    val filtered = if (search.isBlank()) {
        locations
    } else {
        locations.filter { it.name.contains(search, ignoreCase = true) }
    }
    val favorites = filtered.filter { it.isFavorite }
    val others = filtered.filterNot { it.isFavorite }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(text = "Locations", style = MaterialTheme.typography.titleMedium)
                IconButton(onClick = { showAdd = !showAdd }) {
                    Icon(imageVector = Icons.Filled.Add, contentDescription = "Add location")
                }
            }
        }

        item {
            OutlinedTextField(
                value = search,
                onValueChange = { search = it },
                leadingIcon = { Icon(imageVector = Icons.Filled.Search, contentDescription = null) },
                label = { Text("Search locations") },
                modifier = Modifier.fillMaxWidth()
            )
        }

        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(imageVector = Icons.Filled.MyLocation, contentDescription = null)
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(text = "Use Current Location", style = MaterialTheme.typography.titleSmall)
                            Text(text = "Switch back to live GPS conditions.", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    Button(onClick = {
                        viewModel.clearSelectedLocation()
                        onUseCurrentLocation()
                    }) {
                        Text("Use GPS")
                    }
                }
            }
        }

        if (showAdd) {
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it },
                            label = { Text("Name") },
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            OutlinedTextField(
                                value = lat,
                                onValueChange = { lat = it },
                                label = { Text("Latitude") },
                                modifier = Modifier.weight(1f)
                            )
                            OutlinedTextField(
                                value = lon,
                                onValueChange = { lon = it },
                                label = { Text("Longitude") },
                                modifier = Modifier.weight(1f)
                            )
                        }
                        Button(onClick = {
                            val latValue = lat.toDoubleOrNull() ?: return@Button
                            val lonValue = lon.toDoubleOrNull() ?: return@Button
                            viewModel.addLocation(name.ifBlank { "Swim Spot" }, latValue, lonValue)
                            name = ""
                            lat = ""
                            lon = ""
                            showAdd = false
                        }) {
                            Text("Save Location")
                        }
                    }
                }
            }
        }

        if (favorites.isNotEmpty()) {
            item { Text(text = "Favorites", style = MaterialTheme.typography.titleSmall) }
            items(favorites, key = { it.id }) { location ->
                LocationRow(
                    location = location,
                    onDelete = { viewModel.deleteLocation(location) },
                    onToggleFavorite = { viewModel.toggleFavorite(location) },
                    onSelect = {
                        viewModel.selectLocation(location)
                        onSelectLocation(location)
                    }
                )
            }
        }

        if (others.isNotEmpty()) {
            item { Text(text = "All Locations", style = MaterialTheme.typography.titleSmall) }
            items(others, key = { it.id }) { location ->
                LocationRow(
                    location = location,
                    onDelete = { viewModel.deleteLocation(location) },
                    onToggleFavorite = { viewModel.toggleFavorite(location) },
                    onSelect = {
                        viewModel.selectLocation(location)
                        onSelectLocation(location)
                    }
                )
            }
        }
    }
}

@Composable
private fun LocationRow(
    location: SwimLocationEntity,
    onDelete: () -> Unit,
    onToggleFavorite: () -> Unit,
    onSelect: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(text = location.name, style = MaterialTheme.typography.titleSmall)
                Spacer(modifier = Modifier.height(4.dp))
                Text(text = "${location.latitude}, ${location.longitude}")
            }
            Column(horizontalAlignment = Alignment.End) {
                IconButton(onClick = onToggleFavorite) {
                    Icon(
                        imageVector = if (location.isFavorite) Icons.Filled.Star else Icons.Outlined.StarBorder,
                        contentDescription = "Toggle favorite"
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Button(onClick = onDelete) {
                    Text("Remove")
                }
            }
        }
    }
}
