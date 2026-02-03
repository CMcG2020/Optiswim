import Foundation
import SwiftData

// MARK: - Swim Location

@Model
final class SwimLocation {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var isFavorite: Bool
    var lastVisited: Date?
    var customNotes: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        isFavorite: Bool = false,
        lastVisited: Date? = nil,
        customNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isFavorite = isFavorite
        self.lastVisited = lastVisited
        self.customNotes = customNotes
        self.createdAt = Date()
    }
}

// MARK: - User Profile

@Model
final class UserProfile {
    var id: UUID
    var level: SwimmerLevel
    var thresholds: ConditionThresholds
    var weights: FactorWeights
    var notificationPreferences: NotificationPreferences
    var createdAt: Date
    
    init(level: SwimmerLevel = .intermediate) {
        self.id = UUID()
        self.level = level
        self.thresholds = ConditionThresholds.defaults(for: level)
        self.weights = FactorWeights.defaults(for: level)
        self.notificationPreferences = NotificationPreferences()
        self.createdAt = Date()
    }
}

// MARK: - Swimmer Level

enum SwimmerLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case experienced = "Experienced"
    case coldWater = "Cold Water Specialist"
    
    var description: String {
        switch self {
        case .beginner:
            return "New to open water swimming. Requires calm, warm conditions."
        case .intermediate:
            return "Comfortable in varied conditions. Can handle moderate waves."
        case .experienced:
            return "Skilled in challenging conditions and cold water."
        case .coldWater:
            return "Acclimatized to cold water. Focused on wave/wind safety."
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "figure.pool.swim"
        case .intermediate: return "figure.open.water.swim"
        case .experienced: return "figure.surfing"
        case .coldWater: return "snowflake"
        }
    }
}

// MARK: - Condition Thresholds

struct ConditionThresholds: Codable {
    var minWaterTemp: Double        // °C
    var maxWaveHeight: Double       // meters
    var maxWindSpeed: Double        // km/h
    var maxWindGusts: Double        // km/h
    var preferredTide: TidePreference
    var acceptOnshoreWind: Bool
    
    // Absolute safety limits (cannot be customized below these)
    static let absoluteMinTemp: Double = 5.0
    static let absoluteMaxWave: Double = 2.0
    static let absoluteMaxWind: Double = 50.0
    
    static func defaults(for level: SwimmerLevel) -> ConditionThresholds {
        switch level {
        case .beginner:
            return ConditionThresholds(
                minWaterTemp: 20,
                maxWaveHeight: 0.3,
                maxWindSpeed: 15,
                maxWindGusts: 20,
                preferredTide: .slackOrHigh,
                acceptOnshoreWind: false
            )
        case .intermediate:
            return ConditionThresholds(
                minWaterTemp: 16,
                maxWaveHeight: 0.6,
                maxWindSpeed: 20,
                maxWindGusts: 30,
                preferredTide: .any,
                acceptOnshoreWind: true
            )
        case .experienced:
            return ConditionThresholds(
                minWaterTemp: 12,
                maxWaveHeight: 1.0,
                maxWindSpeed: 30,
                maxWindGusts: 45,
                preferredTide: .any,
                acceptOnshoreWind: true
            )
        case .coldWater:
            return ConditionThresholds(
                minWaterTemp: 8,
                maxWaveHeight: 1.0,
                maxWindSpeed: 30,
                maxWindGusts: 45,
                preferredTide: .any,
                acceptOnshoreWind: true
            )
        }
    }
}

// MARK: - Tide Preference

enum TidePreference: String, Codable, CaseIterable {
    case any = "Any"
    case high = "High Tide"
    case low = "Low Tide"
    case slackOrHigh = "Slack or High"
    
    var description: String {
        switch self {
        case .any: return "No preference"
        case .high: return "Prefer high tide for deeper water"
        case .low: return "Prefer low tide for calmer conditions"
        case .slackOrHigh: return "Prefer slack water or high tide"
        }
    }
}

// MARK: - Factor Weights

struct FactorWeights: Codable {
    var temperature: Double     // 0.0 - 1.0
    var wave: Double
    var wind: Double
    var direction: Double
    var weather: Double
    var tide: Double
    
    var total: Double {
        temperature + wave + wind + direction + weather + tide
    }
    
    static func defaults(for level: SwimmerLevel) -> FactorWeights {
        switch level {
        case .beginner:
            return FactorWeights(
                temperature: 0.30,
                wave: 0.25,
                wind: 0.20,
                direction: 0.10,
                weather: 0.10,
                tide: 0.05
            )
        case .intermediate:
            return FactorWeights(
                temperature: 0.25,
                wave: 0.25,
                wind: 0.20,
                direction: 0.10,
                weather: 0.10,
                tide: 0.10
            )
        case .experienced:
            return FactorWeights(
                temperature: 0.15,
                wave: 0.25,
                wind: 0.20,
                direction: 0.15,
                weather: 0.10,
                tide: 0.15
            )
        case .coldWater:
            return FactorWeights(
                temperature: 0.10,
                wave: 0.30,
                wind: 0.25,
                direction: 0.15,
                weather: 0.10,
                tide: 0.10
            )
        }
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var dailyAlertEnabled: Bool
    var dailyAlertHour: Int          // 0-23
    var dailyAlertMinute: Int        // 0-59
    var optimalWindowAlerts: Bool
    var safetyAlertsEnabled: Bool
    var savedLocationUpdates: Bool
    
    init() {
        self.dailyAlertEnabled = true
        self.dailyAlertHour = 6
        self.dailyAlertMinute = 0
        self.optimalWindowAlerts = true
        self.safetyAlertsEnabled = true
        self.savedLocationUpdates = true
    }
    
    var dailyAlertTimeString: String {
        String(format: "%02d:%02d", dailyAlertHour, dailyAlertMinute)
    }
}
