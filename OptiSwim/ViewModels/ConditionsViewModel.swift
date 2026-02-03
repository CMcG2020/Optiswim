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
        isLoading = true
        errorMessage = nil
        currentLocationName = location.name
        
        // Capture values for sendable closure
        let lat = location.latitude
        let lon = location.longitude
        
        do {
            async let conditionsTask = apiService.fetchConditions(
                latitude: lat,
                longitude: lon
            )
            async let forecastTask = apiService.fetchForecast(
                latitude: lat,
                longitude: lon
            )
            
            let (conditions, hourlyForecast) = try await (conditionsTask, forecastTask)
            
            self.currentConditions = conditions
            self.forecast = hourlyForecast
            self.currentScore = ScoringService.calculateScore(conditions: conditions, profile: profile)
            self.optimalWindow = ScoringService.findOptimalWindow(forecast: hourlyForecast, profile: profile)
            self.lastUpdated = Date()
            self.isOffline = false
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to fetch conditions: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func fetchConditionsForCurrentLocation(profile: UserProfile) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let clLocation = try await LocationService.shared.getCurrentLocation()
            let lat = clLocation.coordinate.latitude
            let lon = clLocation.coordinate.longitude
            
            // Update location name asynchronously
            let name = await LocationService.shared.reverseGeocode(location: clLocation)
            currentLocationName = name.isEmpty ? "Current Location" : name
            
            async let conditionsTask = apiService.fetchConditions(
                latitude: lat,
                longitude: lon
            )
            async let forecastTask = apiService.fetchForecast(
                latitude: lat,
                longitude: lon
            )
            
            let (conditions, hourlyForecast) = try await (conditionsTask, forecastTask)
            
            self.currentConditions = conditions
            self.forecast = hourlyForecast
            self.currentScore = ScoringService.calculateScore(conditions: conditions, profile: profile)
            self.optimalWindow = ScoringService.findOptimalWindow(forecast: hourlyForecast, profile: profile)
            self.lastUpdated = Date()
            self.isOffline = false
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to fetch conditions: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    // MARK: - Helpers
    
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
