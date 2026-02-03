import Foundation

// MARK: - Swim Score

struct SwimScore {
    let value: Double                    // 0-100
    let rating: ScoreRating
    let warnings: [SafetyWarning]
    let breakdown: ScoreBreakdown
    let optimalWindow: TimeWindow?
    
    var displayValue: Int {
        Int(value.rounded())
    }
    
    var color: String {
        rating.color
    }
}

// MARK: - Score Rating

enum ScoreRating: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case dangerous = "Dangerous"
    
    var color: String {
        switch self {
        case .excellent, .good: return "green"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .dangerous: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.circle"
        case .poor: return "exclamationmark.triangle"
        case .dangerous: return "xmark.octagon.fill"
        }
    }
    
    var message: String {
        switch self {
        case .excellent: return "Perfect conditions for swimming!"
        case .good: return "Good conditions for swimming"
        case .fair: return "Proceed with caution"
        case .poor: return "Not recommended for swimming"
        case .dangerous: return "Do not swim - dangerous conditions"
        }
    }
    
    static func from(score: Double) -> ScoreRating {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .dangerous
        }
    }
}

// MARK: - Safety Warning

enum SafetyWarning: String, Codable, CaseIterable {
    case dangerousWaves = "Dangerous wave conditions"
    case dangerousWind = "High wind speeds"
    case stormWarning = "Storm warning in effect"
    case coldWaterShock = "Cold water shock risk"
    case strongCurrents = "Strong currents expected"
    case lowVisibility = "Reduced visibility"
    case highUV = "High UV - sun protection needed"
    case rapidTempDrop = "Water temperature dropping"
    case onshoreWind = "Onshore wind creating choppy conditions"
    case gustyConditions = "Gusty conditions expected"
    
    var icon: String {
        switch self {
        case .dangerousWaves: return "water.waves"
        case .dangerousWind, .gustyConditions: return "wind"
        case .stormWarning: return "cloud.bolt.rain.fill"
        case .coldWaterShock: return "thermometer.snowflake"
        case .strongCurrents: return "arrow.left.arrow.right.circle"
        case .lowVisibility: return "eye.slash"
        case .highUV: return "sun.max.trianglebadge.exclamationmark"
        case .rapidTempDrop: return "thermometer.low"
        case .onshoreWind: return "arrow.down.to.line"
        }
    }
    
    var severity: WarningSeverity {
        switch self {
        case .dangerousWaves, .dangerousWind, .stormWarning, .coldWaterShock, .strongCurrents:
            return .critical
        case .lowVisibility, .rapidTempDrop, .gustyConditions:
            return .warning
        case .highUV, .onshoreWind:
            return .info
        }
    }
}

enum WarningSeverity {
    case critical   // Red - Do not swim
    case warning    // Orange - Proceed with caution
    case info       // Yellow - Be aware
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .warning: return "orange"
        case .info: return "yellow"
        }
    }
}

// MARK: - Score Breakdown

struct ScoreBreakdown {
    let temperatureScore: Double
    let waveScore: Double
    let windScore: Double
    let directionScore: Double
    let weatherScore: Double
    let tideScore: Double
    
    var factors: [(name: String, score: Double, icon: String)] {
        [
            ("Water Temp", temperatureScore, "thermometer.medium"),
            ("Waves", waveScore, "water.waves"),
            ("Wind", windScore, "wind"),
            ("Wind Dir", directionScore, "arrow.up.circle"),
            ("Weather", weatherScore, "cloud.sun"),
            ("Tide", tideScore, "arrow.up.arrow.down")
        ]
    }
}

// MARK: - Time Window

struct TimeWindow: Codable {
    let start: Date
    let end: Date
    let averageScore: Double
    
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
    
    var durationString: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
