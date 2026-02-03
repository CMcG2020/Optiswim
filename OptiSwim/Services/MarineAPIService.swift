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
        // Marine API only supports hourly, not current - we'll get the latest hour
        async let marineData = fetchMarineData(latitude: latitude, longitude: longitude)
        async let weatherData = fetchWeatherData(latitude: latitude, longitude: longitude)
        
        let (marine, weather) = try await (marineData, weatherData)
        
        return combineConditions(marine: marine, weather: weather)
    }
    
    // MARK: - Fetch Hourly Forecast
    
    func fetchForecast(latitude: Double, longitude: Double, days: Int = 7) async throws -> [HourlyForecast] {
        async let marineData = fetchMarineForecast(latitude: latitude, longitude: longitude, days: days)
        async let weatherData = fetchWeatherForecast(latitude: latitude, longitude: longitude, days: days)
        
        let (marine, weather) = try await (marineData, weatherData)
        
        return combineForecast(marine: marine, weather: weather)
    }
    
    // MARK: - Marine API
    
    private func fetchMarineData(latitude: Double, longitude: Double) async throws -> MarineAPIResponse {
        var components = URLComponents(string: marineBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            // Marine API uses hourly, get first few hours for "current"
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period,swell_wave_height"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("Marine API error: status \(statusCode)")
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(MarineAPIResponse.self, from: data)
    }
    
    private func fetchMarineForecast(latitude: Double, longitude: Double, days: Int) async throws -> MarineAPIResponse {
        var components = URLComponents(string: marineBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period,swell_wave_height"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
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
            URLQueryItem(name: "timezone", value: "auto")
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
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try decoder.decode(WeatherAPIResponse.self, from: data)
    }
    
    // MARK: - Combine Data
    
    private func combineConditions(marine: MarineAPIResponse, weather: WeatherAPIResponse) -> MarineConditions {
        // Get the most recent hourly data from marine API
        let waveHeight = marine.hourly?.waveHeight?.first ?? 0
        let waveDirection = marine.hourly?.waveDirection?.first ?? 0
        let wavePeriod = marine.hourly?.wavePeriod?.first ?? 0
        let swellHeight = marine.hourly?.swellWaveHeight?.first ?? 0
        
        return MarineConditions(
            timestamp: Date(),
            waveHeight: waveHeight,
            waveDirection: waveDirection,
            wavePeriod: wavePeriod,
            swellHeight: swellHeight,
            waterTemperature: 15, // Default - marine API doesn't provide this
            seaLevel: 0,
            windSpeed: weather.current?.windSpeed10m ?? 0,
            windGusts: weather.current?.windGusts10m ?? 0,
            windDirection: weather.current?.windDirection10m ?? 0,
            weatherCode: weather.current?.weatherCode ?? 0,
            uvIndex: weather.current?.uvIndex ?? 0,
            airTemperature: weather.current?.temperature2m ?? 20,
            precipitation: weather.current?.precipitation ?? 0
        )
    }
    
    private func combineForecast(marine: MarineAPIResponse, weather: WeatherAPIResponse) -> [HourlyForecast] {
        guard let marineHourly = marine.hourly,
              let weatherHourly = weather.hourly,
              let marineTimes = marineHourly.time,
              let _ = weatherHourly.time else {
            return []
        }
        
        var forecasts: [HourlyForecast] = []
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        // Also try simpler format
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        for (index, timeString) in marineTimes.enumerated() {
            var date = dateFormatter.date(from: timeString)
            if date == nil {
                date = simpleDateFormatter.date(from: timeString)
            }
            
            guard let parsedDate = date,
                  index < (marineHourly.waveHeight?.count ?? 0),
                  index < (weatherHourly.temperature2m?.count ?? 0) else {
                continue
            }
            
            let conditions = MarineConditions(
                timestamp: parsedDate,
                waveHeight: marineHourly.waveHeight?[index] ?? 0,
                waveDirection: marineHourly.waveDirection?[index] ?? 0,
                wavePeriod: marineHourly.wavePeriod?[index] ?? 0,
                swellHeight: marineHourly.swellWaveHeight?[index] ?? 0,
                waterTemperature: 15, // Default
                seaLevel: 0,
                windSpeed: weatherHourly.windSpeed10m?[index] ?? 0,
                windGusts: weatherHourly.windGusts10m?[index] ?? 0,
                windDirection: weatherHourly.windDirection10m?[index] ?? 0,
                weatherCode: weatherHourly.weatherCode?[index] ?? 0,
                uvIndex: weatherHourly.uvIndex?[index] ?? 0,
                airTemperature: weatherHourly.temperature2m?[index] ?? 20,
                precipitation: weatherHourly.precipitation?[index] ?? 0
            )
            
            forecasts.append(HourlyForecast(timestamp: parsedDate, conditions: conditions))
        }
        
        return forecasts
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
        
        enum CodingKeys: String, CodingKey {
            case time
            case waveHeight = "wave_height"
            case waveDirection = "wave_direction"
            case wavePeriod = "wave_period"
            case swellWaveHeight = "swell_wave_height"
        }
    }
}

struct WeatherAPIResponse: Codable {
    let current: WeatherCurrent?
    let hourly: WeatherHourly?
    
    struct WeatherCurrent: Codable {
        let temperature2m: Double?
        let weatherCode: Int?
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?
        let precipitation: Double?
        let uvIndex: Double?
        
        enum CodingKeys: String, CodingKey {
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
