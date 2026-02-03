package com.optiswim

import android.app.Application
import dagger.hilt.android.HiltAndroidApp
import com.optiswim.background.NotificationHelper

@HiltAndroidApp
class OptiSwimApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NotificationHelper.ensureChannels(this)
    }
}
