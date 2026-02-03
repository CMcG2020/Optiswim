package com.optiswim.background

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.optiswim.R

object NotificationHelper {
    const val CHANNEL_DAILY = "daily_conditions"
    const val CHANNEL_SAFETY = "safety_alerts"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val daily = NotificationChannel(
            CHANNEL_DAILY,
            "Daily Conditions",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        daily.description = "Daily swim condition summaries"

        val safety = NotificationChannel(
            CHANNEL_SAFETY,
            "Safety Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )
        safety.description = "Critical swim safety alerts"

        manager.createNotificationChannel(daily)
        manager.createNotificationChannel(safety)
    }

    fun showDaily(context: Context, title: String, body: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_DAILY)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        NotificationManagerCompat.from(context).notify(1001, notification)
    }

    fun showSafety(context: Context, title: String, body: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_SAFETY)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        NotificationManagerCompat.from(context).notify(2001, notification)
    }
}
