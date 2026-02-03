package com.optiswim.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.optiswim.data.model.SwimLocationEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SwimLocationDao {
    @Query("SELECT * FROM swim_locations ORDER BY isFavorite DESC, name ASC")
    fun observeLocations(): Flow<List<SwimLocationEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(location: SwimLocationEntity)

    @Delete
    suspend fun delete(location: SwimLocationEntity)
}
