package com.optiswim.data.repository

import com.optiswim.data.model.HourlyForecast
import com.optiswim.data.model.MarineConditions
import com.optiswim.data.remote.MarineApiService
import com.optiswim.data.remote.WeatherApiService
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import kotlin.math.abs

class ConditionsRepository @Inject constructor(
    private val weatherApi: WeatherApiService,
    private val marineApi: MarineApiService
) {
    suspend fun fetchConditions(lat: Double, lon: Double): MarineConditions {
        val marine = runCatching { marineApi.getHourly(lat, lon, days = 2) }.getOrNull()
        val weatherCurrent = weatherApi.getCurrent(lat, lon)
        val weatherHourly = weatherApi.getHourly(lat, lon, days = 2)

        val marineHourly = marine?.hourly
        val marineTimes = parseTimes(marineHourly?.time ?: weatherHourly.hourly?.time)
        val index = nearestIndex(marineTimes, LocalDateTime.now(ZoneOffset.UTC))

        val windSpeed = weatherCurrent.current?.windSpeed
            ?: weatherHourly.hourly?.windSpeed?.getOrNull(index)
            ?: 0.0
        val windGusts = weatherCurrent.current?.windGusts
            ?: weatherHourly.hourly?.windGusts?.getOrNull(index)
            ?: 0.0
        val windDirection = weatherCurrent.current?.windDirection
            ?: weatherHourly.hourly?.windDirection?.getOrNull(index)
            ?: 0.0
        val weatherCode = weatherCurrent.current?.weatherCode
            ?: weatherHourly.hourly?.weatherCode?.getOrNull(index)
            ?: 0
        val uvIndex = weatherCurrent.current?.uvIndex
            ?: weatherHourly.hourly?.uvIndex?.getOrNull(index)
            ?: 0.0
        val airTemperature = weatherCurrent.current?.temperature
            ?: weatherHourly.hourly?.temperature?.getOrNull(index)
            ?: 20.0
        val precipitation = weatherCurrent.current?.precipitation
            ?: weatherHourly.hourly?.precipitation?.getOrNull(index)
            ?: 0.0

        val tidePhase = computeTidePhase(marineTimes, marineHourly?.seaLevelHeight ?: emptyList(), index)

        val timestampFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm")
        val timestamp = marineTimes.getOrNull(index)?.format(timestampFormatter)
            ?: LocalDateTime.now(ZoneOffset.UTC).format(timestampFormatter)

        return MarineConditions(
            timestamp = timestamp,
            waveHeight = marineHourly?.waveHeight?.getOrNull(index) ?: 0.0,
            waveDirection = marineHourly?.waveDirection?.getOrNull(index) ?: 0.0,
            wavePeriod = marineHourly?.wavePeriod?.getOrNull(index) ?: 0.0,
            swellHeight = marineHourly?.swellWaveHeight?.getOrNull(index) ?: 0.0,
            seaLevelHeight = marineHourly?.seaLevelHeight?.getOrNull(index) ?: 0.0,
            seaSurfaceTemperature = marineHourly?.seaSurfaceTemperature?.getOrNull(index) ?: 0.0,
            windSpeed = windSpeed,
            windGusts = windGusts,
            windDirection = windDirection,
            airTemperature = airTemperature,
            uvIndex = uvIndex,
            precipitation = precipitation,
            weatherCode = weatherCode,
            tidePhase = tidePhase,
            sourceUpdateTime = null
        )
    }

    suspend fun fetchForecast(lat: Double, lon: Double, days: Int): List<HourlyForecast> {
        val marine = runCatching { marineApi.getHourly(lat, lon, days = days) }.getOrNull()
        val weather = weatherApi.getHourly(lat, lon, days = days)

        val marineHourly = marine?.hourly
        val weatherHourly = weather.hourly
        val daylightWindows = buildDaylightWindows(weather.daily)

        val marineTimes = parseTimes(marineHourly?.time ?: weatherHourly?.time)
        val marineSize = marineHourly?.waveHeight?.size ?: Int.MAX_VALUE
        val weatherSize = weatherHourly?.temperature?.size ?: 0
        val count = listOf(
            marineTimes.size,
            marineSize,
            weatherSize
        ).minOrNull() ?: 0

        val forecasts = mutableListOf<HourlyForecast>()
        for (i in 0 until count) {
            val tidePhase = computeTidePhase(marineTimes, marineHourly?.seaLevelHeight ?: emptyList(), i)
            val timestamp = marineTimes[i]
            val isDaylight = daylightWindows.takeIf { it.isNotEmpty() }?.any { window ->
                !timestamp.isBefore(window.first) && !timestamp.isAfter(window.second)
            }
            forecasts.add(
                HourlyForecast(
                    timestamp = timestamp.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm")),
                    waveHeight = marineHourly?.waveHeight?.getOrNull(i) ?: 0.0,
                    waveDirection = marineHourly?.waveDirection?.getOrNull(i) ?: 0.0,
                    wavePeriod = marineHourly?.wavePeriod?.getOrNull(i) ?: 0.0,
                    swellHeight = marineHourly?.swellWaveHeight?.getOrNull(i) ?: 0.0,
                    seaLevelHeight = marineHourly?.seaLevelHeight?.getOrNull(i) ?: 0.0,
                    seaSurfaceTemperature = marineHourly?.seaSurfaceTemperature?.getOrNull(i) ?: 0.0,
                    windSpeed = weatherHourly?.windSpeed?.getOrNull(i) ?: 0.0,
                    windGusts = weatherHourly?.windGusts?.getOrNull(i) ?: 0.0,
                    windDirection = weatherHourly?.windDirection?.getOrNull(i) ?: 0.0,
                    airTemperature = weatherHourly?.temperature?.getOrNull(i) ?: 20.0,
                    uvIndex = weatherHourly?.uvIndex?.getOrNull(i) ?: 0.0,
                    precipitation = weatherHourly?.precipitation?.getOrNull(i) ?: 0.0,
                    weatherCode = weatherHourly?.weatherCode?.getOrNull(i) ?: 0,
                    tidePhase = tidePhase,
                    sourceUpdateTime = null,
                    isDaylight = isDaylight
                )
            )
        }

        return forecasts
    }

    private fun parseTimes(values: List<String>?): List<LocalDateTime> {
        if (values == null) return emptyList()
        val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm")
        return values.mapNotNull {
            runCatching { LocalDateTime.parse(it, formatter) }.getOrNull()
        }
    }

    private fun buildDaylightWindows(daily: com.optiswim.data.remote.WeatherDaily?): List<Pair<LocalDateTime, LocalDateTime>> {
        if (daily == null) return emptyList()
        val sunrises = parseTimes(daily.sunrise)
        val sunsets = parseTimes(daily.sunset)
        val count = minOf(sunrises.size, sunsets.size)
        if (count == 0) return emptyList()
        return (0 until count).map { index -> sunrises[index] to sunsets[index] }
    }

    private fun nearestIndex(times: List<LocalDateTime>, target: LocalDateTime): Int {
        if (times.isEmpty()) return 0
        var bestIndex = 0
        var bestDiff = abs(java.time.Duration.between(times[0], target).toMinutes())
        for (i in 1 until times.size) {
            val diff = abs(java.time.Duration.between(times[i], target).toMinutes())
            if (diff < bestDiff) {
                bestDiff = diff
                bestIndex = i
            }
        }
        return bestIndex
    }

    private fun computeTidePhase(times: List<LocalDateTime>, seaLevels: List<Double>, index: Int): String? {
        if (times.isEmpty() || seaLevels.size < 3 || index >= seaLevels.size) return null

        val windowStart = (index - 12).coerceAtLeast(0)
        val windowEnd = (index + 12).coerceAtMost(seaLevels.size)
        val window = seaLevels.subList(windowStart, windowEnd)
        if (window.isEmpty()) return null

        val mean = window.average()
        val detrended = window.map { it - mean }
        val maxLevel = detrended.maxOrNull() ?: return null
        val minLevel = detrended.minOrNull() ?: return null
        val range = maxLevel - minLevel
        if (range == 0.0) return "mid"

        val threshold = 0.05 * range
        val localIndex = index - windowStart
        val currentLevel = detrended[localIndex]

        if (kotlin.math.abs(currentLevel - maxLevel) <= threshold) return "high"
        if (kotlin.math.abs(currentLevel - minLevel) <= threshold) return "low"

        val slope = when {
            index > 0 && index < seaLevels.size - 1 -> seaLevels[index + 1] - seaLevels[index - 1]
            index > 0 -> seaLevels[index] - seaLevels[index - 1]
            else -> seaLevels[index + 1] - seaLevels[index]
        }

        return if (slope > 0) "rising" else "falling"
    }
}
