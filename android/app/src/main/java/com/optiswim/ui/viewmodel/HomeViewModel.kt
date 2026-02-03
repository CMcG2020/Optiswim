package com.optiswim.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.optiswim.data.model.HourlyForecast
import com.optiswim.data.model.MarineConditions
import com.optiswim.data.model.SwimScore
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.data.repository.ConditionsRepository
import com.optiswim.data.repository.PreferencesRepository
import com.optiswim.domain.ScoringService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val conditionsRepository: ConditionsRepository,
    private val preferencesRepository: PreferencesRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val level = preferencesRepository.swimmerLevel.first()
                val conditions = conditionsRepository.fetchConditions(DEFAULT_LAT, DEFAULT_LON)
                val forecast = conditionsRepository.fetchForecast(DEFAULT_LAT, DEFAULT_LON, 7)
                val score = ScoringService.calculateScore(conditions, level)
                _uiState.value = HomeUiState(
                    isLoading = false,
                    conditions = conditions,
                    forecast = forecast,
                    score = score,
                    level = level
                )
            } catch (error: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.localizedMessage)
            }
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
    val level: SwimmerLevel = SwimmerLevel.INTERMEDIATE,
    val error: String? = null
)
