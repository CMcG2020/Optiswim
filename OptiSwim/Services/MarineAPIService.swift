import Foundation

// MARK: - Open-Meteo API Service

actor MarineAPIService {
    static let shared = MarineAPIService()

    private let marineBaseURL = "https://marine-api.open-meteo.com/v1/marine"
    private let weatherBaseURL = "https://api.open-meteo.com/v1/forecast"

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Fetch Current Conditions

    func fetchConditions(latitude: Double, longitude: Double) async throws -> MarineConditions {
        async let marineData = fetchMarineHourly(latitude: latitude, longitude: longitude, days: 2)
        async let weatherCurrent = fetchWeatherData(latitude: latitude, longitude: longitude)
        async let weatherHourly = fetchWeatherForecast(latitude: latitude, longitude: longitude, days: 2)

        let (marine, currentWeather, hourlyWeather) = try await (marineData, weatherCurrent, weatherHourly)
        return combineConditions(marine: marine, weather: currentWeather, hourlyWeather: hourlyWeather)
    }

    // MARK: - Fetch Hourly Forecast

    func fetchForecast(latitude: Double, longitude: Double, days: Int = 7) async throws -> [HourlyForecast] {
        async let marineData = fetchMarineHourly(latitude: latitude, longitude: longitude, days: days)
        async let weatherData = fetchWeatherForecast(latitude: latitude, longitude: longitude, days: days)

        let (marine, weather) = try await (marineData, weatherData)
        return combineForecast(marine: marine, weather: weather)
    }

    // MARK: - Marine API

    private func fetchMarineHourly(latitude: Double, longitude: Double, days: Int) async throws -> MarineAPIResponse {
        var components = URLComponents(string: marineBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period,swell_wave_height,sea_level_height_msl,sea_surface_temperature"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "UTC"),
        ]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(MarineAPIResponse.self, from: data)
    }

    // MARK: - Weather API

    private func fetchWeatherData(latitude: Double, longitude: Double) async throws -> WeatherAPIResponse {
        var components = URLComponents(string: weatherBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,uv_index"),
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(WeatherAPIResponse.self, from: data)
    }

    private func fetchWeatherForecast(latitude: Double, longitude: Double, days: Int) async throws -> WeatherAPIResponse {
        var components = URLComponents(string: weatherBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,uv_index"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(WeatherAPIResponse.self, from: data)
    }

    // MARK: - Combine Data

    private func combineConditions(
        marine: MarineAPIResponse,
        weather: WeatherAPIResponse,
        hourlyWeather: WeatherAPIResponse
    ) -> MarineConditions {
        let marineHourly = marine.hourly
        let marineTimes = parseDates(marineHourly?.time ?? [])
        let now = Date()
        let marineIndex = nearestIndex(in: marineTimes, to: now) ?? 0

        let weatherCurrent = weather.current
        let weatherHourly = hourlyWeather.hourly

        let windSpeed = weatherCurrent?.windSpeed10m ?? weatherHourly?.windSpeed10m?[safe: marineIndex] ?? 0
        let windGusts = weatherCurrent?.windGusts10m ?? weatherHourly?.windGusts10m?[safe: marineIndex] ?? 0
        let windDirection = weatherCurrent?.windDirection10m ?? weatherHourly?.windDirection10m?[safe: marineIndex] ?? 0
        let weatherCode = weatherCurrent?.weatherCode ?? weatherHourly?.weatherCode?[safe: marineIndex] ?? 0
        let uvIndex = weatherCurrent?.uvIndex ?? weatherHourly?.uvIndex?[safe: marineIndex] ?? 0
        let airTemperature = weatherCurrent?.temperature2m ?? weatherHourly?.temperature2m?[safe: marineIndex] ?? 20
        let precipitation = weatherCurrent?.precipitation ?? weatherHourly?.precipitation?[safe: marineIndex] ?? 0

        let tidePhase = computeTidePhase(times: marineTimes, seaLevels: marineHourly?.seaLevelHeight ?? [], index: marineIndex)

        return MarineConditions(
            timestamp: marineTimes[safe: marineIndex] ?? now,
            waveHeight: marineHourly?.waveHeight?[safe: marineIndex] ?? 0,
            waveDirection: marineHourly?.waveDirection?[safe: marineIndex] ?? 0,
            wavePeriod: marineHourly?.wavePeriod?[safe: marineIndex] ?? 0,
            swellHeight: marineHourly?.swellWaveHeight?[safe: marineIndex] ?? 0,
            waterTemperature: marineHourly?.seaSurfaceTemperature?[safe: marineIndex] ?? 0,
            seaLevel: marineHourly?.seaLevelHeight?[safe: marineIndex] ?? 0,
            windSpeed: windSpeed,
            windGusts: windGusts,
            windDirection: windDirection,
            weatherCode: weatherCode,
            uvIndex: uvIndex,
            airTemperature: airTemperature,
            precipitation: precipitation,
            tidePhase: tidePhase,
            sourceUpdateTime: nil
        )
    }

    private func combineForecast(marine: MarineAPIResponse, weather: WeatherAPIResponse) -> [HourlyForecast] {
        guard let marineHourly = marine.hourly,
              let weatherHourly = weather.hourly else {
            return []
        }

        let marineTimes = parseDates(marineHourly.time ?? [])
        let daylightWindows = buildDaylightWindows(daily: weather.daily)
        let count = min(
            marineTimes.count,
            marineHourly.waveHeight?.count ?? 0,
            weatherHourly.temperature2m?.count ?? 0
        )

        var forecasts: [HourlyForecast] = []

        for index in 0..<count {
            let tidePhase = computeTidePhase(
                times: marineTimes,
                seaLevels: marineHourly.seaLevelHeight ?? [],
                index: index
            )

            let timestamp = marineTimes[index]
            let isDaylight: Bool? = daylightWindows.isEmpty
                ? nil
                : daylightWindows.contains { window in
                    timestamp >= window.sunrise && timestamp <= window.sunset
                }

            let conditions = MarineConditions(
                timestamp: timestamp,
                waveHeight: marineHourly.waveHeight?[index] ?? 0,
                waveDirection: marineHourly.waveDirection?[index] ?? 0,
                wavePeriod: marineHourly.wavePeriod?[index] ?? 0,
                swellHeight: marineHourly.swellWaveHeight?[index] ?? 0,
                waterTemperature: marineHourly.seaSurfaceTemperature?[index] ?? 0,
                seaLevel: marineHourly.seaLevelHeight?[index] ?? 0,
                windSpeed: weatherHourly.windSpeed10m?[index] ?? 0,
                windGusts: weatherHourly.windGusts10m?[index] ?? 0,
                windDirection: weatherHourly.windDirection10m?[index] ?? 0,
                weatherCode: weatherHourly.weatherCode?[index] ?? 0,
                uvIndex: weatherHourly.uvIndex?[index] ?? 0,
                airTemperature: weatherHourly.temperature2m?[index] ?? 20,
                precipitation: weatherHourly.precipitation?[index] ?? 0,
                tidePhase: tidePhase,
                sourceUpdateTime: nil
            )

            forecasts.append(HourlyForecast(timestamp: timestamp, conditions: conditions, isDaylight: isDaylight))
        }

        return forecasts
    }

    // MARK: - Helpers

    private func parseDates(_ values: [String]) -> [Date] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm"

        return values.compactMap { value in
            isoFormatter.date(from: value) ?? fallback.date(from: value)
        }
    }

    private func buildDaylightWindows(daily: WeatherAPIResponse.WeatherDaily?) -> [(sunrise: Date, sunset: Date)] {
        guard let daily else { return [] }

        let sunrises = parseDates(daily.sunrise ?? [])
        let sunsets = parseDates(daily.sunset ?? [])
        let count = min(sunrises.count, sunsets.count)

        guard count > 0 else { return [] }

        return (0..<count).map { index in
            (sunrise: sunrises[index], sunset: sunsets[index])
        }
    }

    private func nearestIndex(in dates: [Date], to target: Date) -> Int? {
        guard !dates.isEmpty else { return nil }
        var bestIndex = 0
        var bestDistance = abs(dates[0].timeIntervalSince(target))
        for index in 1..<dates.count {
            let distance = abs(dates[index].timeIntervalSince(target))
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func computeTidePhase(times: [Date], seaLevels: [Double], index: Int) -> TideState? {
        guard seaLevels.count >= 3, times.count == seaLevels.count, index < seaLevels.count else { return nil }

        let windowStart = max(0, index - 12)
        let windowEnd = min(seaLevels.count, index + 12)
        let window = Array(seaLevels[windowStart..<windowEnd])

        guard !window.isEmpty else { return nil }

        let mean = window.reduce(0, +) / Double(window.count)
        let detrended = window.map { $0 - mean }

        guard let maxLevel = detrended.max(), let minLevel = detrended.min() else { return nil }
        let range = maxLevel - minLevel
        if range == 0 {
            return .mid
        }

        let threshold = 0.05 * range
        let localIndex = index - windowStart
        let currentLevel = detrended[localIndex]

        if abs(currentLevel - maxLevel) <= threshold {
            return .high
        }

        if abs(currentLevel - minLevel) <= threshold {
            return .low
        }

        let slope: Double
        if index > 0 && index < seaLevels.count - 1 {
            slope = seaLevels[index + 1] - seaLevels[index - 1]
        } else if index > 0 {
            slope = seaLevels[index] - seaLevels[index - 1]
        } else {
            slope = seaLevels[index + 1] - seaLevels[index]
        }

        return slope > 0 ? .rising : .falling
    }
}

// MARK: - API Response Models

struct MarineAPIResponse: Codable {
    let hourly: MarineHourly?

    struct MarineHourly: Codable {
        let time: [String]?
        let waveHeight: [Double]?
        let waveDirection: [Double]?
        let wavePeriod: [Double]?
        let swellWaveHeight: [Double]?
        let seaLevelHeight: [Double]?
        let seaSurfaceTemperature: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case waveHeight = "wave_height"
            case waveDirection = "wave_direction"
            case wavePeriod = "wave_period"
            case swellWaveHeight = "swell_wave_height"
            case seaLevelHeight = "sea_level_height_msl"
            case seaSurfaceTemperature = "sea_surface_temperature"
        }
    }
}

struct WeatherAPIResponse: Codable {
    let current: WeatherCurrent?
    let hourly: WeatherHourly?
    let daily: WeatherDaily?

    struct WeatherCurrent: Codable {
        let time: String?
        let temperature2m: Double?
        let weatherCode: Int?
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?
        let precipitation: Double?
        let uvIndex: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
            case precipitation
            case uvIndex = "uv_index"
        }
    }

    struct WeatherHourly: Codable {
        let time: [String]?
        let temperature2m: [Double]?
        let weatherCode: [Int]?
        let windSpeed10m: [Double]?
        let windDirection10m: [Double]?
        let windGusts10m: [Double]?
        let precipitation: [Double]?
        let uvIndex: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
            case precipitation
            case uvIndex = "uv_index"
        }
    }

    struct WeatherDaily: Codable {
        let time: [String]?
        let sunrise: [String]?
        let sunset: [String]?

        enum CodingKeys: String, CodingKey {
            case time
            case sunrise
            case sunset
        }
    }
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidResponse
    case decodingError
    case networkError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
