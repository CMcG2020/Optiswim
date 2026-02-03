package com.optiswim.data.repository

import com.optiswim.data.local.SwimLocationDao
import com.optiswim.data.model.SwimLocationEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class LocationsRepository @Inject constructor(
    private val dao: SwimLocationDao
) {
    fun observeLocations(): Flow<List<SwimLocationEntity>> = dao.observeLocations()

    suspend fun save(location: SwimLocationEntity) {
        dao.upsert(location)
    }

    suspend fun delete(location: SwimLocationEntity) {
        dao.delete(location)
    }
}
