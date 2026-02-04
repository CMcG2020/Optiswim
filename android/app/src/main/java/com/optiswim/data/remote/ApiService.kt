package com.optiswim.data.remote

import retrofit2.http.GET
import retrofit2.http.Query

interface WeatherApiService {
    @GET("v1/forecast")
    suspend fun getCurrent(
        @Query("latitude") lat: Double,
        @Query("longitude") lon: Double,
        @Query("current") current: String = "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,uv_index",
        @Query("timezone") timezone: String = "UTC",
        @Query("wind_speed_unit") windSpeedUnit: String = "kmh",
        @Query("temperature_unit") temperatureUnit: String = "celsius"
    ): WeatherResponse

    @GET("v1/forecast")
    suspend fun getHourly(
        @Query("latitude") lat: Double,
        @Query("longitude") lon: Double,
        @Query("hourly") hourly: String = "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,uv_index",
        @Query("daily") daily: String = "sunrise,sunset",
        @Query("forecast_days") days: Int = 7,
        @Query("timezone") timezone: String = "UTC",
        @Query("wind_speed_unit") windSpeedUnit: String = "kmh",
        @Query("temperature_unit") temperatureUnit: String = "celsius"
    ): WeatherResponse
}

interface MarineApiService {
    @GET("v1/marine")
    suspend fun getHourly(
        @Query("latitude") lat: Double,
        @Query("longitude") lon: Double,
        @Query("hourly") hourly: String = "wave_height,wave_direction,wave_period,swell_wave_height,sea_level_height_msl,sea_surface_temperature",
        @Query("forecast_days") days: Int = 7,
        @Query("timezone") timezone: String = "UTC"
    ): MarineResponse
}
