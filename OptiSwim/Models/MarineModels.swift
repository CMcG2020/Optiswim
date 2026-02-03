import Foundation
import SwiftData

// MARK: - Marine Conditions (from API)

struct MarineConditions: Codable {
    let timestamp: Date
    let waveHeight: Double              // meters
    let waveDirection: Double           // degrees
    let wavePeriod: Double              // seconds
    let swellHeight: Double             // meters
    let waterTemperature: Double        // °C
    let seaLevel: Double                // meters (for tide approximation)
    let windSpeed: Double               // km/h
    let windGusts: Double               // km/h
    let windDirection: Double           // degrees
    let weatherCode: Int                // WMO code
    let uvIndex: Double
    let airTemperature: Double          // °C
    let precipitation: Double           // mm
    let tidePhase: TideState?
    let sourceUpdateTime: Date?
    
    var tideState: TideState {
        if let tidePhase {
            return tidePhase
        }

        // Approximate tide state from sea level (fallback)
        if seaLevel > 0.5 {
            return .high
        } else if seaLevel < -0.5 {
            return .low
        } else {
            return .mid
        }
    }
    
    var weatherDescription: String {
        WeatherCode(rawValue: weatherCode)?.description ?? "Unknown"
    }
    
    var weatherIcon: String {
        WeatherCode(rawValue: weatherCode)?.icon ?? "questionmark.circle"
    }
    
    var windDirectionCardinal: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((windDirection + 11.25) / 22.5) % 16
        return directions[index]
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case waveHeight
        case waveDirection
        case wavePeriod
        case swellHeight
        case waterTemperature = "seaSurfaceTemperature"
        case seaLevel = "seaLevelHeight"
        case windSpeed
        case windGusts
        case windDirection
        case weatherCode
        case uvIndex
        case airTemperature
        case precipitation
        case tidePhase
        case sourceUpdateTime
    }
}

// MARK: - Tide State

enum TideState: String, Codable {
    case high = "High"
    case mid = "Mid"
    case low = "Low"
    case rising = "Rising"
    case falling = "Falling"
    
    var icon: String {
        switch self {
        case .high: return "arrow.up.to.line"
        case .low: return "arrow.down.to.line"
        case .mid, .rising, .falling: return "arrow.left.arrow.right"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        switch value {
        case "high": self = .high
        case "low": self = .low
        case "rising": self = .rising
        case "falling": self = .falling
        case "mid": self = .mid
        default: self = .mid
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.lowercased())
    }
}

// MARK: - WMO Weather Codes

enum WeatherCode: Int, Codable {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case depositingFog = 48
    case drizzleLight = 51
    case drizzleModerate = 53
    case drizzleDense = 55
    case freezingDrizzleLight = 56
    case freezingDrizzleDense = 57
    case rainSlight = 61
    case rainModerate = 63
    case rainHeavy = 65
    case freezingRainLight = 66
    case freezingRainHeavy = 67
    case snowSlight = 71
    case snowModerate = 73
    case snowHeavy = 75
    case snowGrains = 77
    case rainShowersSlight = 80
    case rainShowersModerate = 81
    case rainShowersViolent = 82
    case snowShowersSlight = 85
    case snowShowersHeavy = 86
    case thunderstorm = 95
    case thunderstormWithHailSlight = 96
    case thunderstormWithHailHeavy = 99
    
    var description: String {
        switch self {
        case .clearSky: return "Clear sky"
        case .mainlyClear: return "Mainly clear"
        case .partlyCloudy: return "Partly cloudy"
        case .overcast: return "Overcast"
        case .fog, .depositingFog: return "Foggy"
        case .drizzleLight, .drizzleModerate, .drizzleDense: return "Drizzle"
        case .freezingDrizzleLight, .freezingDrizzleDense: return "Freezing drizzle"
        case .rainSlight: return "Light rain"
        case .rainModerate: return "Moderate rain"
        case .rainHeavy: return "Heavy rain"
        case .freezingRainLight, .freezingRainHeavy: return "Freezing rain"
        case .snowSlight, .snowModerate, .snowHeavy, .snowGrains: return "Snow"
        case .rainShowersSlight, .rainShowersModerate, .rainShowersViolent: return "Rain showers"
        case .snowShowersSlight, .snowShowersHeavy: return "Snow showers"
        case .thunderstorm, .thunderstormWithHailSlight, .thunderstormWithHailHeavy: return "Thunderstorm"
        }
    }
    
    var icon: String {
        switch self {
        case .clearSky: return "sun.max.fill"
        case .mainlyClear: return "sun.min.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .fog, .depositingFog: return "cloud.fog.fill"
        case .drizzleLight, .drizzleModerate, .drizzleDense: return "cloud.drizzle.fill"
        case .freezingDrizzleLight, .freezingDrizzleDense: return "cloud.sleet.fill"
        case .rainSlight, .rainModerate: return "cloud.rain.fill"
        case .rainHeavy: return "cloud.heavyrain.fill"
        case .freezingRainLight, .freezingRainHeavy: return "cloud.sleet.fill"
        case .snowSlight, .snowModerate, .snowHeavy, .snowGrains: return "cloud.snow.fill"
        case .rainShowersSlight, .rainShowersModerate, .rainShowersViolent: return "cloud.rain.fill"
        case .snowShowersSlight, .snowShowersHeavy: return "cloud.snow.fill"
        case .thunderstorm, .thunderstormWithHailSlight, .thunderstormWithHailHeavy: return "cloud.bolt.rain.fill"
        }
    }
    
    var isSafeForSwimming: Bool {
        switch self {
        case .clearSky, .mainlyClear, .partlyCloudy, .overcast:
            return true
        case .drizzleLight, .drizzleModerate:
            return true
        default:
            return false
        }
    }
}

// MARK: - Hourly Forecast

struct HourlyForecast: Codable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let conditions: MarineConditions
}

// MARK: - Cached Conditions

@Model
final class CachedConditions {
    var id: UUID
    var locationId: UUID
    var conditionsData: Data      // Encoded MarineConditions
    var forecastData: Data        // Encoded [HourlyForecast]
    var cachedAt: Date
    var expiresAt: Date
    
    init(locationId: UUID, conditions: MarineConditions, forecast: [HourlyForecast]) {
        self.id = UUID()
        self.locationId = locationId
        self.conditionsData = (try? JSONEncoder().encode(conditions)) ?? Data()
        self.forecastData = (try? JSONEncoder().encode(forecast)) ?? Data()
        self.cachedAt = Date()
        self.expiresAt = Date().addingTimeInterval(3600) // 1 hour expiry
    }
    
    var conditions: MarineConditions? {
        try? JSONDecoder().decode(MarineConditions.self, from: conditionsData)
    }
    
    var forecast: [HourlyForecast] {
        (try? JSONDecoder().decode([HourlyForecast].self, from: forecastData)) ?? []
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var isStale: Bool {
        Date() > cachedAt.addingTimeInterval(1800) // 30 minutes
    }
}
