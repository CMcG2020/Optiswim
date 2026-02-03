import SwiftUI
import SwiftData
import MapKit
import UIKit

// MARK: - Native Search Field
struct SearchTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SearchTextField
        
        init(_ parent: SearchTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit()
            return true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.becomeFirstResponder() // Auto-focus
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}

// MARK: - Add Location View
struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var isSearching = false
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Search Section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        SearchTextField(text: $searchQuery, placeholder: "Search beaches...") {
                            // Search already updates on change, but this handles return key
                        }
                        .frame(height: 30) // Give it a fixed height in the Form
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Find Location")
                } footer: {
                    if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                        Text("No results found")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: searchQuery) { _, newValue in
                    Task {
                        await searchLocations(query: newValue)
                    }
                }
                
                // MARK: - Search Results
                if !searchResults.isEmpty && selectedLocation == nil {
                    Section("Results") {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectLocation(item)
                            } label: {
                                VStack(alignment: .leading) {
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
                
                // MARK: - Selected Location Details
                if let selected = selectedLocation {
                    Section {
                        Map(position: $cameraPosition) {
                            Marker(selected.name ?? "Location", coordinate: selected.location.coordinate)
                        }
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                        
                        Button("Choose Different Location") {
                            withAnimation {
                                selectedLocation = nil
                                searchQuery = ""
                            }
                        }
                        .foregroundStyle(.cyan)
                    } header: {
                        Text("Selected Map")
                    }
                    
                    Section("Location Details") {
                        TextField("Name", text: $name)
                            .textContentType(.location)
                        
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                        
                        Toggle("Add to Favorites", isOn: $isFavorite)
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(selectedLocation == nil || name.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func formatAddress(from mapItem: MKMapItem) -> String {
        // Use the new address property directly (iOS 26+)
        if let address = mapItem.address {
            // MKAddress provides a formatted description
            return String(describing: address)
        }
        
        // Fallback for name or unknown
        return mapItem.name ?? "Unknown Location"
    }
    
    private func searchLocations(query: String) async {
        guard query.count >= 3 else {
            if query.isEmpty {
                await MainActor.run { searchResults = [] }
            }
            return
        }
        
        await MainActor.run { isSearching = true }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query + " beach"
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            await MainActor.run {
                searchResults = Array(response.mapItems.prefix(10))
                isSearching = false
            }
        } catch {
            await MainActor.run { 
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        withAnimation {
            selectedLocation = item
            name = item.name ?? ""
            
            let region = MKCoordinateRegion(
                center: item.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            cameraPosition = .region(region)
        }
    }
    
    private func saveLocation() {
        guard let selected = selectedLocation else { return }
        
        let coord = selected.location.coordinate
        
        let swimLocation = SwimLocation(
            name: name,
            latitude: coord.latitude,
            longitude: coord.longitude,
            isFavorite: isFavorite,
            customNotes: notes.isEmpty ? nil : notes
        )
        
        modelContext.insert(swimLocation)
        dismiss()
    }
}

#Preview {
    AddLocationView()
}
