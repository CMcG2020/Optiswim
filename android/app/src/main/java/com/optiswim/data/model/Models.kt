package com.optiswim.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class MarineConditions(
    val timestamp: String,
    val waveHeight: Double,
    val waveDirection: Double,
    val wavePeriod: Double,
    val swellHeight: Double,
    @Json(name = "seaLevelHeight") val seaLevelHeight: Double,
    @Json(name = "seaSurfaceTemperature") val seaSurfaceTemperature: Double,
    val windSpeed: Double,
    val windGusts: Double,
    val windDirection: Double,
    val airTemperature: Double,
    val uvIndex: Double,
    val precipitation: Double,
    val weatherCode: Int,
    val tidePhase: String? = null,
    val sourceUpdateTime: String? = null
)

@JsonClass(generateAdapter = true)
data class HourlyForecast(
    val timestamp: String,
    val waveHeight: Double,
    val waveDirection: Double,
    val wavePeriod: Double,
    val swellHeight: Double,
    @Json(name = "seaLevelHeight") val seaLevelHeight: Double,
    @Json(name = "seaSurfaceTemperature") val seaSurfaceTemperature: Double,
    val windSpeed: Double,
    val windGusts: Double,
    val windDirection: Double,
    val airTemperature: Double,
    val uvIndex: Double,
    val precipitation: Double,
    val weatherCode: Int,
    val tidePhase: String? = null,
    val sourceUpdateTime: String? = null
)


@Entity(tableName = "swim_locations")
data class SwimLocationEntity(
    @PrimaryKey val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val isFavorite: Boolean = false,
    val notes: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val lastVisited: Long? = null
)

enum class SwimmerLevel(val label: String) {
    BEGINNER("Beginner"),
    INTERMEDIATE("Intermediate"),
    EXPERIENCED("Experienced"),
    COLD_WATER("Cold Water Specialist")
}

enum class TidePreference(val label: String) {
    ANY("Any"),
    HIGH("High Tide"),
    LOW("Low Tide"),
    SLACK_OR_HIGH("Slack or High")
}

data class ConditionThresholds(
    val minWaterTemp: Double,
    val maxWaveHeight: Double,
    val maxWindSpeed: Double,
    val maxWindGusts: Double,
    val preferredTide: TidePreference,
    val acceptOnshoreWind: Boolean
)

data class FactorWeights(
    val temperature: Double,
    val wave: Double,
    val wind: Double,
    val direction: Double,
    val weather: Double,
    val tide: Double
)

sealed class ScoreRating(val label: String) {
    data object Excellent : ScoreRating("Excellent")
    data object Good : ScoreRating("Good")
    data object Fair : ScoreRating("Fair")
    data object Poor : ScoreRating("Poor")
    data object Dangerous : ScoreRating("Dangerous")
}

data class SwimScore(
    val value: Double,
    val rating: ScoreRating,
    val warnings: List<String>
)
