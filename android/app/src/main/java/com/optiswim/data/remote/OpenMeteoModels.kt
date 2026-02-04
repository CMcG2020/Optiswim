package com.optiswim.data.remote

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class WeatherResponse(
    val current: WeatherCurrent? = null,
    val hourly: WeatherHourly? = null,
    val daily: WeatherDaily? = null
)

@JsonClass(generateAdapter = true)
data class WeatherCurrent(
    val time: String? = null,
    @Json(name = "temperature_2m") val temperature: Double? = null,
    @Json(name = "weather_code") val weatherCode: Int? = null,
    @Json(name = "wind_speed_10m") val windSpeed: Double? = null,
    @Json(name = "wind_direction_10m") val windDirection: Double? = null,
    @Json(name = "wind_gusts_10m") val windGusts: Double? = null,
    val precipitation: Double? = null,
    @Json(name = "uv_index") val uvIndex: Double? = null
)

@JsonClass(generateAdapter = true)
data class WeatherHourly(
    val time: List<String>? = null,
    @Json(name = "temperature_2m") val temperature: List<Double>? = null,
    @Json(name = "weather_code") val weatherCode: List<Int>? = null,
    @Json(name = "wind_speed_10m") val windSpeed: List<Double>? = null,
    @Json(name = "wind_direction_10m") val windDirection: List<Double>? = null,
    @Json(name = "wind_gusts_10m") val windGusts: List<Double>? = null,
    val precipitation: List<Double>? = null,
    @Json(name = "uv_index") val uvIndex: List<Double>? = null
)

@JsonClass(generateAdapter = true)
data class WeatherDaily(
    val time: List<String>? = null,
    val sunrise: List<String>? = null,
    val sunset: List<String>? = null
)

@JsonClass(generateAdapter = true)
data class MarineResponse(
    val hourly: MarineHourly? = null
)

@JsonClass(generateAdapter = true)
data class MarineHourly(
    val time: List<String>? = null,
    @Json(name = "wave_height") val waveHeight: List<Double>? = null,
    @Json(name = "wave_direction") val waveDirection: List<Double>? = null,
    @Json(name = "wave_period") val wavePeriod: List<Double>? = null,
    @Json(name = "swell_wave_height") val swellWaveHeight: List<Double>? = null,
    @Json(name = "sea_level_height_msl") val seaLevelHeight: List<Double>? = null,
    @Json(name = "sea_surface_temperature") val seaSurfaceTemperature: List<Double>? = null
)
