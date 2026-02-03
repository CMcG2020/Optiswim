package com.optiswim.background

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

object AlertScheduler {
    private const val DAILY_WORK_NAME = "daily_conditions"
    private const val SAFETY_WORK_NAME = "safety_conditions"

    fun scheduleDaily(context: Context) {
        val request = PeriodicWorkRequestBuilder<AlertWorker>(24, TimeUnit.HOURS)
            .setConstraints(defaultConstraints())
            .setInputData(workDataOf(AlertWorker.KEY_TYPE to AlertWorker.TYPE_DAILY))
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            DAILY_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }

    fun scheduleSafety(context: Context) {
        val request = PeriodicWorkRequestBuilder<AlertWorker>(6, TimeUnit.HOURS)
            .setConstraints(defaultConstraints())
            .setInputData(workDataOf(AlertWorker.KEY_TYPE to AlertWorker.TYPE_SAFETY))
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            SAFETY_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }

    fun cancelAll(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(DAILY_WORK_NAME)
        WorkManager.getInstance(context).cancelUniqueWork(SAFETY_WORK_NAME)
    }

    private fun defaultConstraints() = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()
}
