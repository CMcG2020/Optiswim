import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var showingProfileEditor = false
    @State private var showingNotificationSettings = false
    @State private var showingThresholdEditor = false
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    
    private var profile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    Button {
                        showingProfileEditor = true
                    } label: {
                        HStack {
                            Image(systemName: profile.level.icon)
                                .font(.title2)
                                .foregroundStyle(.cyan)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading) {
                                Text("Swimmer Profile")
                                    .font(.headline)
                                Text(profile.level.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Condition Preferences
                Section("Condition Preferences") {
                    Button {
                        showingThresholdEditor = true
                    } label: {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            iconColor: .orange,
                            title: "Custom Thresholds",
                            subtitle: "Adjust your ideal conditions"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink {
                        WeightEditorView(profile: profile)
                    } label: {
                        SettingsRow(
                            icon: "chart.pie",
                            iconColor: .purple,
                            title: "Scoring Weights",
                            subtitle: "Adjust factor importance"
                        )
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        SettingsRow(
                            icon: "bell.badge",
                            iconColor: .red,
                            title: "Alert Settings",
                            subtitle: profile.notificationPreferences.dailyAlertEnabled ? 
                                "Daily at \(profile.notificationPreferences.dailyAlertTimeString)" : "Disabled"
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://open-meteo.com")!) {
                        SettingsRow(
                            icon: "cloud",
                            iconColor: .blue,
                            title: "Weather Data",
                            subtitle: "Powered by Open-Meteo"
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingProfileEditor) {
                ProfileEditorView(profile: profile)
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView(profile: profile)
            }
            .sheet(isPresented: $showingThresholdEditor) {
                ThresholdEditorView(profile: profile)
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Profile Editor

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    
    var body: some View {
        NavigationStack {
            List {
                Section("Select Your Level") {
                    ForEach(SwimmerLevel.allCases, id: \.self) { level in
                        Button {
                            profile.level = level
                            // Reset to defaults for new level
                            profile.thresholds = ConditionThresholds.defaults(for: level)
                            profile.weights = FactorWeights.defaults(for: level)
                        } label: {
                            HStack {
                                Image(systemName: level.icon)
                                    .font(.title2)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading) {
                                    Text(level.rawValue)
                                        .font(.headline)
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if profile.level == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    Text("Changing your level will reset your condition thresholds and scoring weights to the recommended defaults for that level.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Swimmer Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Threshold Editor

struct ThresholdEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Water Temperature") {
                    VStack(alignment: .leading) {
                        Text("Minimum: \(Int(profile.thresholds.minWaterTemp))°C")
                        Slider(
                            value: $profile.thresholds.minWaterTemp,
                            in: ConditionThresholds.absoluteMinTemp...30,
                            step: 1
                        )
                    }
                }
                
                Section("Wave Height") {
                    VStack(alignment: .leading) {
                        Text("Maximum: \(String(format: "%.1f", profile.thresholds.maxWaveHeight))m")
                        Slider(
                            value: $profile.thresholds.maxWaveHeight,
                            in: 0.1...ConditionThresholds.absoluteMaxWave,
                            step: 0.1
                        )
                    }
                }
                
                Section("Wind") {
                    VStack(alignment: .leading) {
                        Text("Max Speed: \(Int(profile.thresholds.maxWindSpeed)) km/h")
                        Slider(
                            value: $profile.thresholds.maxWindSpeed,
                            in: 5...ConditionThresholds.absoluteMaxWind,
                            step: 5
                        )
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Max Gusts: \(Int(profile.thresholds.maxWindGusts)) km/h")
                        Slider(
                            value: $profile.thresholds.maxWindGusts,
                            in: 10...60,
                            step: 5
                        )
                    }
                    
                    Toggle("Accept Onshore Wind", isOn: $profile.thresholds.acceptOnshoreWind)
                }
                
                Section("Tide Preference") {
                    Picker("Preferred Tide", selection: $profile.thresholds.preferredTide) {
                        ForEach(TidePreference.allCases, id: \.self) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        profile.thresholds = ConditionThresholds.defaults(for: profile.level)
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Condition Thresholds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Weight Editor

struct WeightEditorView: View {
    @Bindable var profile: UserProfile
    
    var body: some View {
        Form {
            Section("Factor Importance") {
                WeightSlider(label: "Water Temperature", icon: "thermometer.medium", value: $profile.weights.temperature)
                WeightSlider(label: "Wave Height", icon: "water.waves", value: $profile.weights.wave)
                WeightSlider(label: "Wind Speed", icon: "wind", value: $profile.weights.wind)
                WeightSlider(label: "Wind Direction", icon: "arrow.up.circle", value: $profile.weights.direction)
                WeightSlider(label: "Weather", icon: "cloud.sun", value: $profile.weights.weather)
                WeightSlider(label: "Tide", icon: "arrow.up.arrow.down", value: $profile.weights.tide)
            }
            
            Section {
                HStack {
                    Text("Total")
                    Spacer()
                    Text(String(format: "%.0f%%", profile.weights.total * 100))
                        .foregroundStyle(profile.weights.total == 1.0 ? .green : .orange)
                }
            } footer: {
                Text("Weights should total 100% for accurate scoring. Current total: \(String(format: "%.0f%%", profile.weights.total * 100))")
            }
            
            Section {
                Button("Reset to Defaults") {
                    profile.weights = FactorWeights.defaults(for: profile.level)
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Scoring Weights")
    }
}

struct WeightSlider: View {
    let label: String
    let icon: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.cyan)
                Text(label)
                Spacer()
                Text("\(Int(value * 100))%")
                    .monospacedDigit()
            }
            Slider(value: $value, in: 0...0.5, step: 0.05)
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile
    
    @State private var alertTime: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Alert") {
                    Toggle("Enable Daily Alert", isOn: $profile.notificationPreferences.dailyAlertEnabled)
                    
                    if profile.notificationPreferences.dailyAlertEnabled {
                        DatePicker(
                            "Alert Time",
                            selection: $alertTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: alertTime) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            profile.notificationPreferences.dailyAlertHour = components.hour ?? 6
                            profile.notificationPreferences.dailyAlertMinute = components.minute ?? 0
                        }
                    }
                }
                
                Section("Other Alerts") {
                    Toggle("Optimal Window Alerts", isOn: $profile.notificationPreferences.optimalWindowAlerts)
                    Toggle("Safety Alerts", isOn: $profile.notificationPreferences.safetyAlertsEnabled)
                    Toggle("Saved Location Updates", isOn: $profile.notificationPreferences.savedLocationUpdates)
                }
                
                Section {
                    Text("Safety alerts cannot be fully disabled to ensure you're always warned about dangerous conditions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                var components = DateComponents()
                components.hour = profile.notificationPreferences.dailyAlertHour
                components.minute = profile.notificationPreferences.dailyAlertMinute
                alertTime = Calendar.current.date(from: components) ?? Date()
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
