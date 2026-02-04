import Foundation
import SwiftData
import CoreLocation

@MainActor
@Observable
final class ConditionsViewModel {
    // MARK: - State
    var currentConditions: MarineConditions?
    var currentScore: SwimScore?
    var forecast: [HourlyForecast] = []
    var optimalWindow: TimeWindow?
    
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var isOffline = false
    
    // MARK: - Dependencies
    private let apiService = MarineAPIService.shared
    
    var currentLocationName: String = "Current Location"
    
    // MARK: - Fetch Conditions
    
    func fetchConditions(for location: SwimLocation, profile: UserProfile) async {
        await fetchConditions(
            latitude: location.latitude,
            longitude: location.longitude,
            profile: profile,
            locationName: location.name
        )
    }
    
    func fetchConditionsForCurrentLocation(profile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let clLocation = try await LocationService.shared.getCurrentLocation()
            let name = await LocationService.shared.reverseGeocode(location: clLocation)
            let locationName = name.isEmpty ? "Current Location" : name
            
            try await fetchConditionsInternal(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
                profile: profile,
                locationName: locationName
            )
        } catch {
            errorMessage = "Failed to fetch conditions: \(error.localizedDescription)"
        }
    }
    
    func fetchConditionsForNearestBeach(profile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let clLocation = try await LocationService.shared.getCurrentLocation()

            if let nearestBeach = await LocationService.shared.findNearestBeach(near: clLocation) {
                try await fetchConditionsInternal(
                    latitude: nearestBeach.coordinate.latitude,
                    longitude: nearestBeach.coordinate.longitude,
                    profile: profile,
                    locationName: nearestBeach.name
                )
            } else {
                let name = await LocationService.shared.reverseGeocode(location: clLocation)
                let locationName = name.isEmpty ? "Current Location" : name

                try await fetchConditionsInternal(
                    latitude: clLocation.coordinate.latitude,
                    longitude: clLocation.coordinate.longitude,
                    profile: profile,
                    locationName: locationName
                )
            }
        } catch {
            errorMessage = "Failed to fetch conditions: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helpers
    
    private func fetchConditions(
        latitude: Double,
        longitude: Double,
        profile: UserProfile,
        locationName: String
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await fetchConditionsInternal(
                latitude: latitude,
                longitude: longitude,
                profile: profile,
                locationName: locationName
            )
        } catch {
            errorMessage = "Failed to fetch conditions: \(error.localizedDescription)"
        }
    }
    
    private func fetchConditionsInternal(
        latitude: Double,
        longitude: Double,
        profile: UserProfile,
        locationName: String
    ) async throws {
        currentLocationName = locationName
        
        async let conditionsTask = apiService.fetchConditions(
            latitude: latitude,
            longitude: longitude
        )
        async let forecastTask = apiService.fetchForecast(
            latitude: latitude,
            longitude: longitude
        )
        
        let (conditions, hourlyForecast) = try await (conditionsTask, forecastTask)
        
        currentConditions = conditions
        forecast = hourlyForecast
        currentScore = ScoringService.calculateScore(conditions: conditions, profile: profile)
        optimalWindow = ScoringService.findOptimalWindow(forecast: hourlyForecast, profile: profile)
        lastUpdated = Date()
        isOffline = false
    }
    
    var lastUpdatedString: String {
        guard let lastUpdated else { return "Never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
    
    var statusIndicator: (icon: String, color: String, text: String) {
        if isLoading {
            return ("arrow.triangle.2.circlepath", "blue", "Updating...")
        } else if errorMessage != nil {
            return ("exclamationmark.circle", "orange", "Error")
        } else if isOffline {
            return ("wifi.slash", "orange", "Offline")
        } else if let lastUpdated {
            let age = Date().timeIntervalSince(lastUpdated)
            if age < 1800 { // 30 minutes
                return ("checkmark.circle.fill", "green", "Live")
            } else {
                return ("clock", "yellow", "Updated \(lastUpdatedString)")
            }
        } else {
            return ("circle.dashed", "gray", "Tap to refresh")
        }
    }
}
