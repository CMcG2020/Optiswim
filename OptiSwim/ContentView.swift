import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            LocationsView()
                .tabItem {
                    Label("Locations", systemImage: "mappin.and.ellipse")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.cyan)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SwimLocation.self, UserProfile.self], inMemory: true)
}
