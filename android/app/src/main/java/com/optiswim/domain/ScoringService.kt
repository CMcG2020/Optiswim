package com.optiswim.domain

import com.optiswim.data.model.ConditionThresholds
import com.optiswim.data.model.FactorWeights
import com.optiswim.data.model.MarineConditions
import com.optiswim.data.model.ScoreRating
import com.optiswim.data.model.SwimScore
import com.optiswim.data.model.SwimmerLevel
import com.optiswim.data.model.TidePreference

object DefaultProfiles {
    fun thresholds(level: SwimmerLevel): ConditionThresholds = when (level) {
        SwimmerLevel.BEGINNER -> ConditionThresholds(20.0, 0.3, 15.0, 20.0, TidePreference.SLACK_OR_HIGH, false)
        SwimmerLevel.INTERMEDIATE -> ConditionThresholds(16.0, 0.6, 20.0, 30.0, TidePreference.ANY, true)
        SwimmerLevel.EXPERIENCED -> ConditionThresholds(12.0, 1.0, 30.0, 45.0, TidePreference.ANY, true)
        SwimmerLevel.COLD_WATER -> ConditionThresholds(8.0, 1.0, 30.0, 45.0, TidePreference.ANY, true)
    }

    fun weights(level: SwimmerLevel): FactorWeights = when (level) {
        SwimmerLevel.BEGINNER -> FactorWeights(0.30, 0.25, 0.20, 0.10, 0.10, 0.05)
        SwimmerLevel.INTERMEDIATE -> FactorWeights(0.25, 0.25, 0.20, 0.10, 0.10, 0.10)
        SwimmerLevel.EXPERIENCED -> FactorWeights(0.15, 0.25, 0.20, 0.10, 0.15, 0.15)
        SwimmerLevel.COLD_WATER -> FactorWeights(0.10, 0.30, 0.25, 0.10, 0.10, 0.15)
    }
}

object ScoringService {
    private const val ABSOLUTE_MIN_TEMP = 5.0
    private const val ABSOLUTE_MAX_WAVE = 2.0
    private const val ABSOLUTE_MAX_WIND = 50.0

    fun calculateScore(conditions: MarineConditions, level: SwimmerLevel): SwimScore {
        val thresholds = DefaultProfiles.thresholds(level)
        val weights = DefaultProfiles.weights(level)

        if (conditions.waveHeight > ABSOLUTE_MAX_WAVE) {
            return SwimScore(0.0, ScoreRating.Dangerous, listOf("Dangerous wave conditions"))
        }

        if (conditions.windSpeed > ABSOLUTE_MAX_WIND) {
            return SwimScore(0.0, ScoreRating.Dangerous, listOf("Dangerous wind conditions"))
        }

        val tempScore = tempScore(conditions.seaSurfaceTemperature, thresholds)
        val waveScore = waveScore(conditions.waveHeight, thresholds)
        val windScore = windScore(conditions.windSpeed, conditions.windGusts, thresholds)
        val directionScore = if (isOnshore(conditions.windDirection) && !thresholds.acceptOnshoreWind) 0.5 else 1.0
        val weatherScore = weatherScore(conditions.weatherCode)
        val tideScore = tideScore(resolveTideState(conditions), thresholds.preferredTide)

        val weighted = (tempScore * weights.temperature) +
            (waveScore * weights.wave) +
            (windScore * weights.wind) +
            (directionScore * weights.direction) +
            (weatherScore * weights.weather) +
            (tideScore * weights.tide)

        val finalScore = (weighted * 100).coerceIn(0.0, 100.0)
        val rating = when {
            finalScore >= 85 -> ScoreRating.Excellent
            finalScore >= 70 -> ScoreRating.Good
            finalScore >= 55 -> ScoreRating.Fair
            finalScore >= 40 -> ScoreRating.Poor
            else -> ScoreRating.Dangerous
        }

        return SwimScore(finalScore, rating, warnings(conditions, thresholds))
    }

    private fun tempScore(temp: Double, thresholds: ConditionThresholds): Double = when {
        temp >= 22 && temp <= 25 -> 1.0
        temp >= thresholds.minWaterTemp -> (1.0 - (kotlin.math.abs(temp - 23.5) * 0.05)).coerceAtLeast(0.6)
        temp >= ABSOLUTE_MIN_TEMP -> ((temp - ABSOLUTE_MIN_TEMP) / (thresholds.minWaterTemp - ABSOLUTE_MIN_TEMP) * 0.5).coerceAtLeast(0.1)
        else -> 0.0
    }

    private fun waveScore(height: Double, thresholds: ConditionThresholds): Double = when {
        height <= 0.2 -> 1.0
        height <= thresholds.maxWaveHeight -> (1.0 - (height - 0.2) / (thresholds.maxWaveHeight - 0.2)).coerceAtLeast(0.6)
        height <= ABSOLUTE_MAX_WAVE -> ((1.0 - (height - thresholds.maxWaveHeight) / (ABSOLUTE_MAX_WAVE - thresholds.maxWaveHeight)) * 0.5).coerceAtLeast(0.1)
        else -> 0.0
    }

    private fun windScore(speed: Double, gusts: Double, thresholds: ConditionThresholds): Double {
        var score = when {
            speed <= 10 -> 1.0
            speed <= thresholds.maxWindSpeed -> (1.0 - (speed - 10) / (thresholds.maxWindSpeed - 10)).coerceAtLeast(0.6)
            speed <= ABSOLUTE_MAX_WIND -> ((1.0 - (speed - thresholds.maxWindSpeed) / (ABSOLUTE_MAX_WIND - thresholds.maxWindSpeed)) * 0.5).coerceAtLeast(0.1)
            else -> 0.0
        }

        if (gusts > thresholds.maxWindGusts) {
            score *= 0.7
        } else if (gusts > speed * 1.5) {
            score *= 0.85
        }

        return score
    }

    private fun weatherScore(code: Int): Double = when (code) {
        0 -> 1.0
        1 -> 0.95
        2 -> 0.9
        3 -> 0.75
        51 -> 0.6
        53, 55 -> 0.4
        45, 48 -> 0.3
        else -> 0.2
    }

    private fun tideScore(state: String, preference: TidePreference): Double {
        val normalized = if (state == "rising" || state == "falling") "mid" else state
        return when (preference) {
            TidePreference.ANY -> 1.0
            TidePreference.HIGH -> if (normalized == "high") 1.0 else if (normalized == "mid") 0.7 else 0.5
            TidePreference.LOW -> if (normalized == "low") 1.0 else if (normalized == "mid") 0.7 else 0.5
            TidePreference.SLACK_OR_HIGH -> if (normalized == "high" || normalized == "mid") 1.0 else 0.6
        }
    }

    private fun resolveTideState(conditions: MarineConditions): String {
        conditions.tidePhase?.let { return it.lowercase() }
        return when {
            conditions.seaLevelHeight > 0.5 -> "high"
            conditions.seaLevelHeight < -0.5 -> "low"
            else -> "mid"
        }
    }

    private fun warnings(conditions: MarineConditions, thresholds: ConditionThresholds): List<String> {
        val warnings = mutableListOf<String>()
        if (conditions.seaSurfaceTemperature < 15) warnings.add("Cold water shock risk")
        if (conditions.waveHeight > thresholds.maxWaveHeight * 0.8) warnings.add("Higher waves expected")
        if (conditions.windSpeed > thresholds.maxWindSpeed * 0.8) warnings.add("Wind approaching limit")
        if (conditions.windGusts > conditions.windSpeed * 1.5) warnings.add("Gusty conditions")
        if (conditions.uvIndex >= 6) warnings.add("High UV index")
        return warnings
    }

    private fun isOnshore(direction: Double): Boolean {
        return direction in 180.0..360.0
    }
}
