import Foundation
import SwiftData
import Network

// MARK: - Cache Manager

@MainActor
final class CacheManager {
    static let shared = CacheManager()
    
    private init() {}
    
    // MARK: - Cache Operations
    
    func cacheConditions(
        locationId: UUID,
        conditions: MarineConditions,
        forecast: [HourlyForecast],
        context: ModelContext
    ) {
        // Remove existing cache for this location
        let descriptor = FetchDescriptor<CachedConditions>(
            predicate: #Predicate { $0.locationId == locationId }
        )
        
        if let existing = try? context.fetch(descriptor) {
            for cache in existing {
                context.delete(cache)
            }
        }
        
        // Create new cache
        let cache = CachedConditions(
            locationId: locationId,
            conditions: conditions,
            forecast: forecast
        )
        
        context.insert(cache)
    }
    
    func loadCachedConditions(for locationId: UUID, context: ModelContext) -> CachedConditions? {
        let descriptor = FetchDescriptor<CachedConditions>(
            predicate: #Predicate { $0.locationId == locationId }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    func clearExpiredCache(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<CachedConditions>(
            predicate: #Predicate { $0.expiresAt < now }
        )
        
        if let expired = try? context.fetch(descriptor) {
            for cache in expired {
                context.delete(cache)
            }
        }
    }
    
    func clearAllCache(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedConditions>()
        
        if let all = try? context.fetch(descriptor) {
            for cache in all {
                context.delete(cache)
            }
        }
    }
}

// MARK: - Network Monitor

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected = true
    var connectionType: ConnectionType = .unknown
    
    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case unknown
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    nonisolated private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .unknown
        }
    }
}
