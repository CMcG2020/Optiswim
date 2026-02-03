package com.optiswim.background

import android.content.Context
import androidx.room.Room
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.optiswim.data.local.AppDatabase
import com.optiswim.data.model.SwimLocationEntity
import com.optiswim.data.repository.ConditionsRepository
import com.optiswim.data.repository.PreferencesRepository
import com.optiswim.data.remote.MarineApiService
import com.optiswim.data.remote.WeatherApiService
import com.optiswim.domain.ScoringService
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.flow.first
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

class AlertWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        val alertType = inputData.getString(KEY_TYPE) ?: TYPE_DAILY

        return runCatching {
            NotificationHelper.ensureChannels(applicationContext)

            val conditionsRepo = createRepository()
            val preferences = PreferencesRepository(applicationContext)
            val level = preferences.swimmerLevel.first()

            val location = getPreferredLocation() ?: DEFAULT_LOCATION
            val conditions = conditionsRepo.fetchConditions(location.latitude, location.longitude)
            val score = ScoringService.calculateScore(conditions, level)

            when (alertType) {
                TYPE_SAFETY -> {
                    if (score.rating is com.optiswim.data.model.ScoreRating.Dangerous || score.warnings.isNotEmpty()) {
                        val body = score.warnings.firstOrNull() ?: "Unsafe conditions detected."
                        NotificationHelper.showSafety(
                            applicationContext,
                            "Swimming Safety Alert",
                            body
                        )
                    }
                }
                else -> {
                    val body = "Score ${score.value.toInt()}/100 - ${score.rating.label}"
                    NotificationHelper.showDaily(
                        applicationContext,
                        "Daily Swim Conditions",
                        body
                    )
                }
            }
        }.fold(
            onSuccess = { Result.success() },
            onFailure = { Result.retry() }
        )
    }

    private fun createRepository(): ConditionsRepository {
        val moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
        val client = OkHttpClient.Builder().build()

        val weatherService = Retrofit.Builder()
            .baseUrl(com.optiswim.BuildConfig.OPEN_METEO_BASE_URL)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .client(client)
            .build()
            .create(WeatherApiService::class.java)

        val marineService = Retrofit.Builder()
            .baseUrl(com.optiswim.BuildConfig.OPEN_METEO_MARINE_BASE_URL)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .client(client)
            .build()
            .create(MarineApiService::class.java)

        return ConditionsRepository(weatherService, marineService)
    }

    private suspend fun getPreferredLocation(): SwimLocationEntity? {
        val db = Room.databaseBuilder(
            applicationContext,
            AppDatabase::class.java,
            "optiswim.db"
        ).build()
        return try {
            val locations = db.swimLocationDao().observeLocations().first()
            locations.firstOrNull { it.isFavorite } ?: locations.firstOrNull()
        } finally {
            db.close()
        }
    }

    companion object {
        const val KEY_TYPE = "alert_type"
        const val TYPE_DAILY = "daily"
        const val TYPE_SAFETY = "safety"
        private val DEFAULT_LOCATION = SwimLocationEntity(
            id = "default",
            name = "Default",
            latitude = 37.7749,
            longitude = -122.4194
        )
    }
}
