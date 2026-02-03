import SwiftUI
import SwiftData
import MapKit

struct LocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwimLocation.name) private var locations: [SwimLocation]
    
    @State private var showingAddLocation = false
    @State private var searchText = ""
    
    var filteredLocations: [SwimLocation] {
        if searchText.isEmpty {
            return locations
        }
        return locations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var favoriteLocations: [SwimLocation] {
        filteredLocations.filter { $0.isFavorite }
    }
    
    var otherLocations: [SwimLocation] {
        filteredLocations.filter { !$0.isFavorite }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !favoriteLocations.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteLocations) { location in
                            LocationRowView(location: location)
                        }
                        .onDelete { indexSet in
                            deleteLocations(from: favoriteLocations, at: indexSet)
                        }
                    }
                }
                
                if !otherLocations.isEmpty {
                    Section("All Locations") {
                        ForEach(otherLocations) { location in
                            LocationRowView(location: location)
                        }
                        .onDelete { indexSet in
                            deleteLocations(from: otherLocations, at: indexSet)
                        }
                    }
                }
                
                if locations.isEmpty {
                    ContentUnavailableView(
                        "No Saved Locations",
                        systemImage: "mappin.slash",
                        description: Text("Add your favorite swim spots to quickly check conditions.")
                    )
                }
            }
            .navigationTitle("Locations")
            .searchable(text: $searchText, prompt: "Search locations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView()
            }
        }
    }
    
    private func deleteLocations(from list: [SwimLocation], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

// MARK: - Location Row

struct LocationRowView: View {
    @Bindable var location: SwimLocation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                
                Text(coordinateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let notes = location.customNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button {
                location.isFavorite.toggle()
            } label: {
                Image(systemName: location.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(location.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private var coordinateString: String {
        let lat = String(format: "%.4f", location.latitude)
        let lon = String(format: "%.4f", location.longitude)
        return "\(lat), \(lon)"
    }
}

#Preview {
    LocationsView()
        .modelContainer(for: SwimLocation.self, inMemory: true)
}
