package com.optiswim.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.optiswim.data.model.SelectedLocation
import com.optiswim.data.model.SwimLocationEntity
import com.optiswim.data.repository.LocationsRepository
import com.optiswim.data.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class LocationsViewModel @Inject constructor(
    private val locationsRepository: LocationsRepository,
    private val preferencesRepository: PreferencesRepository
) : ViewModel() {
    val locations: StateFlow<List<SwimLocationEntity>> =
        locationsRepository.observeLocations()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun addLocation(name: String, latitude: Double, longitude: Double) {
        viewModelScope.launch {
            val location = SwimLocationEntity(
                id = UUID.randomUUID().toString(),
                name = name,
                latitude = latitude,
                longitude = longitude
            )
            locationsRepository.save(location)
        }
    }

    fun deleteLocation(location: SwimLocationEntity) {
        viewModelScope.launch {
            locationsRepository.delete(location)
        }
    }

    fun toggleFavorite(location: SwimLocationEntity) {
        viewModelScope.launch {
            locationsRepository.save(location.copy(isFavorite = !location.isFavorite))
        }
    }

    fun selectLocation(location: SwimLocationEntity) {
        viewModelScope.launch {
            preferencesRepository.setSelectedLocation(
                SelectedLocation(
                    name = location.name,
                    latitude = location.latitude,
                    longitude = location.longitude
                )
            )
        }
    }

    fun clearSelectedLocation() {
        viewModelScope.launch {
            preferencesRepository.setSelectedLocation(null)
        }
    }
}
