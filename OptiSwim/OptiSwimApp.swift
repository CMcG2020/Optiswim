import SwiftUI
import SwiftData

@main
struct OptiSwimApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SwimLocation.self,
            UserProfile.self,
            CachedConditions.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
