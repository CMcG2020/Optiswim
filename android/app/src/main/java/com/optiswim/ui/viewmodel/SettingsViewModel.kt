package com.optiswim.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.data.repository.PreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val preferencesRepository: PreferencesRepository
) : ViewModel() {
    val swimmerLevel: StateFlow<SwimmerLevel> =
        preferencesRepository.swimmerLevel
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), SwimmerLevel.INTERMEDIATE)

    val dailyAlerts: StateFlow<Boolean> =
        preferencesRepository.dailyAlertsEnabled
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    fun updateLevel(level: SwimmerLevel) {
        viewModelScope.launch {
            preferencesRepository.setSwimmerLevel(level)
        }
    }

    fun setDailyAlerts(enabled: Boolean) {
        viewModelScope.launch {
            preferencesRepository.setDailyAlerts(enabled)
        }
    }
}
