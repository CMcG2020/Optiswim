package com.optiswim.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.optiswim.data.model.SwimLocationEntity

@Database(entities = [SwimLocationEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun swimLocationDao(): SwimLocationDao
}
