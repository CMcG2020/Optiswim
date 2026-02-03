package com.optiswim.data.repository

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.optiswim.data.model.SwimmerLevel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

private val Context.dataStore by preferencesDataStore("optiswim_prefs")

class PreferencesRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val levelKey = stringPreferencesKey("swimmer_level")
    private val dailyAlertsKey = booleanPreferencesKey("daily_alerts")
    private val currentLocationAlertsKey = booleanPreferencesKey("current_location_alerts")

    val swimmerLevel: Flow<SwimmerLevel> = context.dataStore.data.map { prefs ->
        val value = prefs[levelKey] ?: SwimmerLevel.INTERMEDIATE.name
        runCatching { SwimmerLevel.valueOf(value) }.getOrDefault(SwimmerLevel.INTERMEDIATE)
    }

    val dailyAlertsEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[dailyAlertsKey] ?: false
    }

    val useCurrentLocationAlerts: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[currentLocationAlertsKey] ?: false
    }

    suspend fun setSwimmerLevel(level: SwimmerLevel) {
        context.dataStore.edit { prefs ->
            prefs[levelKey] = level.name
        }
    }

    suspend fun setDailyAlerts(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[dailyAlertsKey] = enabled
        }
    }

    suspend fun setUseCurrentLocationAlerts(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[currentLocationAlertsKey] = enabled
        }
    }
}
