package com.optiswim.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.optiswim.data.model.HourlyForecast
import com.optiswim.data.model.MarineConditions
import com.optiswim.data.model.SelectedLocation
import com.optiswim.data.model.SwimScore
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.data.model.TimeWindow
import com.optiswim.data.repository.ConditionsRepository
import com.optiswim.data.repository.PreferencesRepository
import com.optiswim.domain.ScoringService
import com.optiswim.location.LocationProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val conditionsRepository: ConditionsRepository,
    private val preferencesRepository: PreferencesRepository,
    private val locationProvider: LocationProvider
) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            preferencesRepository.selectedLocation
                .distinctUntilChanged()
                .drop(1)
                .collect {
                    refresh(useDeviceLocation = true)
                }
        }
    }

    fun refresh(useDeviceLocation: Boolean) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val level = preferencesRepository.swimmerLevel.first()
                val selectedLocation = preferencesRepository.selectedLocation.first()
                val deviceLocation = if (useDeviceLocation && selectedLocation == null) {
                    locationProvider.getCurrentLocation()
                } else {
                    null
                }

                val lat = when {
                    selectedLocation != null -> selectedLocation.latitude
                    deviceLocation != null -> deviceLocation.latitude
                    else -> DEFAULT_LAT
                }
                val lon = when {
                    selectedLocation != null -> selectedLocation.longitude
                    deviceLocation != null -> deviceLocation.longitude
                    else -> DEFAULT_LON
                }
                val label = when {
                    selectedLocation != null -> selectedLocation.name
                    deviceLocation != null -> "Current Location"
                    else -> "Default Location"
                }

                val conditions = conditionsRepository.fetchConditions(lat, lon)
                val forecast = conditionsRepository.fetchForecast(lat, lon, 7)
                val score = ScoringService.calculateScore(conditions, level)
                val optimalWindow = ScoringService.findOptimalWindow(forecast, level)
                _uiState.value = HomeUiState(
                    isLoading = false,
                    conditions = conditions,
                    forecast = forecast,
                    score = score,
                    optimalWindow = optimalWindow,
                    level = level,
                    locationLabel = label,
                    usingDeviceLocation = deviceLocation != null,
                    selectedLocation = selectedLocation
                )
            } catch (error: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.localizedMessage)
            }
        }
    }

    fun clearSelectedLocation() {
        viewModelScope.launch {
            preferencesRepository.setSelectedLocation(null)
        }
    }

    companion object {
        private const val DEFAULT_LAT = 37.7749
        private const val DEFAULT_LON = -122.4194
    }
}

data class HomeUiState(
    val isLoading: Boolean = false,
    val conditions: MarineConditions? = null,
    val forecast: List<HourlyForecast> = emptyList(),
    val score: SwimScore? = null,
    val optimalWindow: TimeWindow? = null,
    val level: SwimmerLevel = SwimmerLevel.INTERMEDIATE,
    val error: String? = null,
    val locationLabel: String = "Default Location",
    val usingDeviceLocation: Boolean = false,
    val selectedLocation: SelectedLocation? = null
)
