import SwiftUI
import SwiftData
import MapKit

struct LocationsView: View {
    @Binding var selectedTab: Int
    @Binding var selectedLocation: SwimLocation?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SwimLocation.name) private var locations: [SwimLocation]
    
    @State private var showingAddLocation = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    
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
                if isSearching {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.9)
                            Text("Searching nearby locations...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                if !searchResults.isEmpty {
                    Section("Search Results") {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                addLocation(from: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "Unknown")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text(formatAddress(from: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                if !favoriteLocations.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteLocations) { location in
                            LocationRowView(location: location) {
                                selectedLocation = location
                                selectedTab = 0
                            }
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
                
                if locations.isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Saved Locations",
                        systemImage: "mappin.slash",
                        description: Text("Add your favorite swim spots to quickly check conditions.")
                    )
                } else if !searchText.isEmpty && filteredLocations.isEmpty && searchResults.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or add a new location.")
                    )
                }
            }
            .navigationTitle("Locations")
            .searchable(text: $searchText, prompt: "Search locations")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    await searchLocations(query: newValue)
                }
            }
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
    
    @MainActor
    private func searchLocations(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 3 else {
            isSearching = false
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            if Task.isCancelled { return }
            
            searchResults = Array(response.mapItems.prefix(10))
            isSearching = false
        } catch {
            if Task.isCancelled { return }
            searchResults = []
            isSearching = false
        }
    }
    
    private func addLocation(from item: MKMapItem) {
        let coord = item.location.coordinate
        if locations.contains(where: {
            abs($0.latitude - coord.latitude) < 0.0001 &&
            abs($0.longitude - coord.longitude) < 0.0001
        }) {
            return
        }
        
        let name = item.name ?? "New Location"
        let swimLocation = SwimLocation(
            name: name,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        
        modelContext.insert(swimLocation)
        searchText = ""
        searchResults = []
    }
    
    private func formatAddress(from mapItem: MKMapItem) -> String {
        if let address = mapItem.address {
            return String(describing: address)
        }
        return mapItem.name ?? "Unknown Location"
    }
}

// MARK: - Location Row

struct LocationRowView: View {
    @Bindable var location: SwimLocation
    var onSelect: (() -> Void)?
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
    }
    
    private var coordinateString: String {
        let lat = String(format: "%.4f", location.latitude)
        let lon = String(format: "%.4f", location.longitude)
        return "\(lat), \(lon)"
    }
}

#Preview {
    LocationsView(selectedTab: .constant(1), selectedLocation: .constant(nil))
        .modelContainer(for: SwimLocation.self, inMemory: true)
}
