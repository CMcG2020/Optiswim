import Foundation
import CoreLocation
import MapKit

// MARK: - Location Service

@MainActor
@Observable
final class LocationService: NSObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false
    var errorMessage: String?
    
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var needsAuthorization: Bool {
        authorizationStatus == .notDetermined
    }
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Request Authorization
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Get Current Location
    
    func getCurrentLocation() async throws -> CLLocation {
        guard isAuthorized else {
            throw LocationError.notAuthorized
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    // MARK: - Geocoding (iOS 26+ MapKit APIs)
    
    nonisolated func reverseGeocode(location: CLLocation) async -> String {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "beach"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                if let name = item.name {
                    return name
                }
            }
        } catch {
            print("Reverse geocoding error: \(error)")
        }
        
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    nonisolated func geocode(address: String) async throws -> CLLocation {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        guard let item = response.mapItems.first else {
            throw LocationError.geocodingFailed
        }
        
        return item.location
    }

    nonisolated func findNearestBeach(near location: CLLocation) async -> (name: String, coordinate: CLLocationCoordinate2D)? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "beach"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 50000,
            longitudinalMeters: 50000
        )

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let candidates = response.mapItems.map { item -> (MKMapItem, CLLocation) in
                let itemLocation = item.location
                return (item, itemLocation)
            }

            guard let nearest = candidates.min(by: { lhs, rhs in
                lhs.1.distance(from: location) < rhs.1.distance(from: location)
            }) else {
                return nil
            }

            let name = nearest.0.name ?? "Nearby Beach"
            return (name, nearest.1.coordinate)
        } catch {
            print("Nearest beach search error: \(error)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Capture location data immediately to avoid sending manager across actors
        guard let location = locations.last else { return }
        let capturedLocation = location
        
        Task { @MainActor in
            currentLocation = capturedLocation
            locationContinuation?.resume(returning: capturedLocation)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Capture error description to avoid sending error across actors
        let errorDesc = error.localizedDescription
        
        Task { @MainActor in
            errorMessage = errorDesc
            locationContinuation?.resume(throwing: LocationError.geocodingFailed)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture status value to avoid sending manager across actors
        let status = manager.authorizationStatus
        
        Task { @MainActor in
            authorizationStatus = status
            
            if status == .denied || status == .restricted {
                errorMessage = "Location access denied. Please enable in Settings."
            }
        }
    }
}

// MARK: - Location Errors

enum LocationError: Error, LocalizedError, Sendable {
    case notAuthorized
    case locationFailed(Error)
    case geocodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location services not authorized"
        case .locationFailed(let error):
            return "Failed to get location: \(error.localizedDescription)"
        case .geocodingFailed:
            return "Failed to find location from address"
        }
    }
}
