import Foundation

// MARK: - Scoring Service

struct ScoringService {
    
    // MARK: - Calculate Swim Score
    
    static func calculateScore(
        conditions: MarineConditions,
        profile: UserProfile
    ) -> SwimScore {
        let thresholds = profile.thresholds
        let weights = profile.weights
        
        var warnings: [SafetyWarning] = []
        
        // 1. Check hard safety limits (instant disqualification)
        if conditions.waveHeight > ConditionThresholds.absoluteMaxWave {
            return SwimScore(
                value: 0,
                rating: .dangerous,
                warnings: [.dangerousWaves],
                breakdown: zeroBreakdown(),
                optimalWindow: nil
            )
        }
        
        if conditions.windSpeed > ConditionThresholds.absoluteMaxWind {
            return SwimScore(
                value: 0,
                rating: .dangerous,
                warnings: [.dangerousWind],
                breakdown: zeroBreakdown(),
                optimalWindow: nil
            )
        }
        
        let isSafe = WeatherCode(rawValue: conditions.weatherCode)?.isSafeForSwimming ?? true
        if !isSafe {
            if conditions.weatherCode >= 95 { // Thunderstorm
                return SwimScore(
                    value: 0,
                    rating: .dangerous,
                    warnings: [.stormWarning],
                    breakdown: zeroBreakdown(),
                    optimalWindow: nil
                )
            }
        }
        
        // 2. Calculate individual factor scores
        let tempScore = calculateTempScore(conditions.waterTemperature, thresholds: thresholds)
        let waveScore = calculateWaveScore(conditions.waveHeight, thresholds: thresholds)
        let windScore = calculateWindScore(conditions.windSpeed, gusts: conditions.windGusts, thresholds: thresholds)
        let directionScore = calculateDirectionScore(conditions.windDirection, acceptOnshore: thresholds.acceptOnshoreWind)
        let weatherScore = calculateWeatherScore(conditions.weatherCode)
        let tideScore = calculateTideScore(conditions.tideState, preference: thresholds.preferredTide)
        
        // 3. Apply weights
        let weightedScore = (tempScore * weights.temperature) +
                           (waveScore * weights.wave) +
                           (windScore * weights.wind) +
                           (directionScore * weights.direction) +
                           (weatherScore * weights.weather) +
                           (tideScore * weights.tide)
        
        // Normalize to 0-100
        let finalScore = min(100, max(0, weightedScore * 100))
        
        // 4. Generate warnings
        warnings = generateWarnings(conditions: conditions, thresholds: thresholds)
        
        let breakdown = ScoreBreakdown(
            temperatureScore: tempScore * 100,
            waveScore: waveScore * 100,
            windScore: windScore * 100,
            directionScore: directionScore * 100,
            weatherScore: weatherScore * 100,
            tideScore: tideScore * 100
        )
        
        return SwimScore(
            value: finalScore,
            rating: ScoreRating.from(score: finalScore),
            warnings: warnings,
            breakdown: breakdown,
            optimalWindow: nil
        )
    }
    
    // MARK: - Find Optimal Window
    
    static func findOptimalWindow(
        forecast: [HourlyForecast],
        profile: UserProfile,
        minDuration: TimeInterval = 7200 // 2 hours
    ) -> TimeWindow? {
        guard forecast.count >= 2 else { return nil }
        
        // Score each hour
        let scores = forecast.map { hour -> (Date, Double) in
            let score = calculateScore(conditions: hour.conditions, profile: profile)
            return (hour.timestamp, score.value)
        }
        
        // Find the best consecutive window
        var bestWindow: TimeWindow?
        var bestAverageScore: Double = 0
        
        let minHours = Int(minDuration / 3600)
        
        for i in 0..<(scores.count - minHours + 1) {
            let windowScores = scores[i..<(i + minHours)]
            let averageScore = windowScores.map { $0.1 }.reduce(0, +) / Double(minHours)
            
            // Only consider windows with good scores (>= 60)
            if averageScore >= 60 && averageScore > bestAverageScore {
                bestAverageScore = averageScore
                bestWindow = TimeWindow(
                    start: windowScores.first!.0,
                    end: windowScores.last!.0.addingTimeInterval(3600),
                    averageScore: averageScore
                )
            }
        }
        
        return bestWindow
    }
    
    // MARK: - Individual Score Calculations
    
    private static func calculateTempScore(_ temp: Double, thresholds: ConditionThresholds) -> Double {
        // Perfect: 22-25°C
        // Good: within user threshold
        // Poor: approaching cold water shock
        
        if temp >= 22 && temp <= 25 {
            return 1.0
        } else if temp >= thresholds.minWaterTemp {
            let distance = min(abs(temp - 22), abs(temp - 25))
            return max(0.6, 1.0 - (distance * 0.05))
        } else if temp >= ConditionThresholds.absoluteMinTemp {
            let ratio = (temp - ConditionThresholds.absoluteMinTemp) / (thresholds.minWaterTemp - ConditionThresholds.absoluteMinTemp)
            return max(0.1, ratio * 0.5)
        } else {
            return 0.0
        }
    }
    
    private static func calculateWaveScore(_ height: Double, thresholds: ConditionThresholds) -> Double {
        // Perfect: < 0.2m
        // Good: within threshold
        // Poor: approaching dangerous
        
        if height <= 0.2 {
            return 1.0
        } else if height <= thresholds.maxWaveHeight {
            let ratio = 1.0 - (height - 0.2) / (thresholds.maxWaveHeight - 0.2)
            return max(0.6, ratio)
        } else if height <= ConditionThresholds.absoluteMaxWave {
            let ratio = 1.0 - (height - thresholds.maxWaveHeight) / (ConditionThresholds.absoluteMaxWave - thresholds.maxWaveHeight)
            return max(0.1, ratio * 0.5)
        } else {
            return 0.0
        }
    }
    
    private static func calculateWindScore(_ speed: Double, gusts: Double, thresholds: ConditionThresholds) -> Double {
        // Perfect: < 10 km/h
        // Good: within threshold
        // Poor: gusty or approaching dangerous
        
        var score: Double = 1.0
        
        if speed <= 10 {
            score = 1.0
        } else if speed <= thresholds.maxWindSpeed {
            let ratio = 1.0 - (speed - 10) / (thresholds.maxWindSpeed - 10)
            score = max(0.6, ratio)
        } else if speed <= ConditionThresholds.absoluteMaxWind {
            let ratio = 1.0 - (speed - thresholds.maxWindSpeed) / (ConditionThresholds.absoluteMaxWind - thresholds.maxWindSpeed)
            score = max(0.1, ratio * 0.5)
        } else {
            score = 0.0
        }
        
        // Penalize gusty conditions
        if gusts > thresholds.maxWindGusts {
            score *= 0.7
        } else if gusts > speed * 1.5 {
            score *= 0.85
        }
        
        return score
    }
    
    private static func calculateDirectionScore(_ direction: Double, acceptOnshore: Bool) -> Double {
        // This is simplified - in reality you'd need coast orientation
        // For now, assume onshore is from 180-360° (south to north through west)
        
        let isOnshore = direction >= 180 && direction <= 360
        
        if isOnshore && !acceptOnshore {
            return 0.5
        }
        
        return 1.0
    }
    
    private static func calculateWeatherScore(_ code: Int) -> Double {
        guard let weather = WeatherCode(rawValue: code) else {
            return 0.5
        }
        
        switch weather {
        case .clearSky:
            return 1.0
        case .mainlyClear:
            return 0.95
        case .partlyCloudy:
            return 0.9
        case .overcast:
            return 0.75
        case .drizzleLight:
            return 0.6
        case .drizzleModerate, .drizzleDense:
            return 0.4
        case .fog, .depositingFog:
            return 0.3
        default:
            return 0.2
        }
    }
    
    private static func calculateTideScore(_ state: TideState, preference: TidePreference) -> Double {
        let normalizedState: TideState = (state == .rising || state == .falling) ? .mid : state
        switch preference {
        case .any:
            return 1.0
        case .high:
            return normalizedState == .high ? 1.0 : (normalizedState == .mid ? 0.7 : 0.5)
        case .low:
            return normalizedState == .low ? 1.0 : (normalizedState == .mid ? 0.7 : 0.5)
        case .slackOrHigh:
            return (normalizedState == .high || normalizedState == .mid) ? 1.0 : 0.6
        }
    }
    
    // MARK: - Generate Warnings
    
    private static func generateWarnings(conditions: MarineConditions, thresholds: ConditionThresholds) -> [SafetyWarning] {
        var warnings: [SafetyWarning] = []
        
        // Cold water warning
        if conditions.waterTemperature < 15 {
            warnings.append(.coldWaterShock)
        }
        
        // Wave warnings
        if conditions.waveHeight > thresholds.maxWaveHeight * 0.8 {
            warnings.append(.dangerousWaves)
        }
        
        // Wind warnings
        if conditions.windSpeed > thresholds.maxWindSpeed * 0.8 {
            warnings.append(.dangerousWind)
        }
        
        if conditions.windGusts > conditions.windSpeed * 1.5 {
            warnings.append(.gustyConditions)
        }
        
        // UV warning
        if conditions.uvIndex >= 6 {
            warnings.append(.highUV)
        }
        
        // Visibility warning
        if let weather = WeatherCode(rawValue: conditions.weatherCode),
           weather == .fog || weather == .depositingFog {
            warnings.append(.lowVisibility)
        }
        
        // Onshore wind warning
        let isOnshore = conditions.windDirection >= 180 && conditions.windDirection <= 360
        if isOnshore && !thresholds.acceptOnshoreWind && conditions.windSpeed > 10 {
            warnings.append(.onshoreWind)
        }
        
        return warnings
    }
    
    private static func zeroBreakdown() -> ScoreBreakdown {
        ScoreBreakdown(
            temperatureScore: 0,
            waveScore: 0,
            windScore: 0,
            directionScore: 0,
            weatherScore: 0,
            tideScore: 0
        )
    }
}
