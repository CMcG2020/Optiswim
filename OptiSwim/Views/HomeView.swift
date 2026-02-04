import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedLocation: SwimLocation?
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<SwimLocation> { $0.isFavorite }, sort: \SwimLocation.name)
    private var favoriteLocations: [SwimLocation]
    
    @State private var viewModel = ConditionsViewModel()
    @State private var showingOnboarding = false
    @State private var showingLocationAlert = false
    
    private var profile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Header
                    StatusHeaderView(viewModel: viewModel)
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
                        ErrorBannerView(message: error) {
                            viewModel.errorMessage = nil
                        }
                    }
                    
                    // Main Score Card
                    if let score = viewModel.currentScore {
                        ScoreCardView(score: score)
                    } else if viewModel.isLoading {
                        LoadingCardView()
                    } else {
                        EmptyStateCardView {
                            checkAndFetchConditions()
                        }
                    }
                    
                    // Optimal Window
                    if let window = viewModel.optimalWindow {
                        OptimalWindowCard(window: window)
                    }
                    
                    // Current Conditions
                    if let conditions = viewModel.currentConditions {
                        ConditionsGridView(conditions: conditions)
                    }

                    // Forecast Chart
                    if !viewModel.forecast.isEmpty {
                        ForecastChartCard(forecast: viewModel.forecast)
                    }
                    
                    // Warnings
                    if let score = viewModel.currentScore, !score.warnings.isEmpty {
                        WarningsView(warnings: score.warnings)
                    }
                    
                    // Favorite Locations Quick Access
                    if !favoriteLocations.isEmpty {
                        FavoriteLocationsSection(
                            locations: favoriteLocations,
                            onSelect: { location in
                                Task {
                                    await viewModel.fetchConditions(for: location, profile: profile)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        checkAndFetchConditions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await fetchConditionsWithLocationCheck()
            }
            .task {
                // Create profile if needed
                if profiles.isEmpty {
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    showingOnboarding = true
                }
            }
            .onChange(of: selectedLocation?.id) { _, _ in
                guard let location = selectedLocation else { return }
                Task {
                    await viewModel.fetchConditions(for: location, profile: profile)
                    selectedLocation = nil
                }
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .alert("Location Access Required", isPresented: $showingLocationAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("OptiSwim needs location access to show swimming conditions. Please enable it in Settings.")
            }
        }
    }
    
    private func checkAndFetchConditions() {
        Task {
            await fetchConditionsWithLocationCheck()
        }
    }
    
    private func fetchConditionsWithLocationCheck() async {
        let locationService = LocationService.shared
        
        // Check authorization
        if locationService.needsAuthorization {
            locationService.requestAuthorization()
            // Wait a bit for the user to respond
            try? await Task.sleep(for: .seconds(1))
        }
        
        if locationService.isAuthorized {
            await viewModel.fetchConditionsForNearestBeach(profile: profile)
        } else if locationService.authorizationStatus == .denied ||
                  locationService.authorizationStatus == .restricted {
            showingLocationAlert = true
            viewModel.isLoading = false
        } else {
            // Still waiting for authorization
            viewModel.isLoading = false
        }
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.subheadline)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Status Header

struct StatusHeaderView: View {
    let viewModel: ConditionsViewModel
    
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundStyle(.cyan)
            
            Text(viewModel.currentLocationName)
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: viewModel.statusIndicator.icon)
                }
                Text(viewModel.statusIndicator.text)
                    .font(.caption)
            }
            .foregroundStyle(statusColor)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch viewModel.statusIndicator.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        default: return .gray
        }
    }
}

// MARK: - Score Card

struct ScoreCardView: View {
    let score: SwimScore
    
    var body: some View {
        VStack(spacing: 16) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: CGFloat(score.value / 100))
                    .stroke(
                        scoreGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: score.value)
                
                VStack(spacing: 4) {
                    Text("\(score.displayValue)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text(score.rating.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            
            // Rating Message
            Text(score.rating.message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Score Breakdown
            ScoreBreakdownView(breakdown: score.breakdown)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var scoreGradient: AngularGradient {
        AngularGradient(
            colors: [.cyan, scoreColor],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * score.value / 100)
        )
    }
    
    private var scoreColor: Color {
        switch score.rating {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .orange
        case .dangerous: return .red
        }
    }
}

// MARK: - Score Breakdown

struct ScoreBreakdownView: View {
    let breakdown: ScoreBreakdown
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(breakdown.factors, id: \.name) { factor in
                VStack(spacing: 4) {
                    Image(systemName: factor.icon)
                        .font(.title3)
                        .foregroundStyle(colorFor(score: factor.score))
                    
                    Text("\(Int(factor.score))")
                        .font(.caption.bold())
                    
                    Text(factor.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func colorFor(score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .cyan
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
}

// MARK: - Optimal Window Card

struct OptimalWindowCard: View {
    let window: TimeWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.green)
                Text("Optimal Swim Window")
                    .font(.headline)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(window.timeRangeString)
                        .font(.title2.bold())
                    Text(window.durationString)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(window.averageScore))")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Conditions Grid

struct ConditionsGridView: View {
    let conditions: MarineConditions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ConditionCell(
                    icon: "thermometer.medium",
                    title: "Water Temp",
                    value: String(format: "%.1f°C", conditions.waterTemperature),
                    color: .cyan
                )
                
                ConditionCell(
                    icon: "water.waves",
                    title: "Wave Height",
                    value: String(format: "%.1fm", conditions.waveHeight),
                    color: .blue
                )
                
                ConditionCell(
                    icon: "wind",
                    title: "Wind",
                    value: "\(Int(conditions.windSpeed)) km/h \(conditions.windDirectionCardinal)",
                    color: .teal
                )
                
                ConditionCell(
                    icon: conditions.weatherIcon,
                    title: "Weather",
                    value: conditions.weatherDescription,
                    color: .orange
                )
                
                ConditionCell(
                    icon: "sun.max.fill",
                    title: "UV Index",
                    value: String(format: "%.0f", conditions.uvIndex),
                    color: .yellow
                )
                
                ConditionCell(
                    icon: conditions.tideState.icon,
                    title: "Tide",
                    value: conditions.tideState.rawValue,
                    color: .indigo
                )
            }

            TideTrendIndicator(state: conditions.tideState)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Tide Trend Indicator

struct TideTrendIndicator: View {
    let state: TideState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("Tide Trend: \(label)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        switch state {
        case .rising: return "Rising"
        case .falling: return "Falling"
        case .high: return "High"
        case .low: return "Low"
        case .mid: return "Mid"
        }
    }

    private var icon: String {
        switch state {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .high: return "arrow.up.to.line"
        case .low: return "arrow.down.to.line"
        case .mid: return "arrow.left.and.right"
        }
    }

    private var color: Color {
        switch state {
        case .rising, .high: return .cyan
        case .falling, .low: return .indigo
        case .mid: return .gray
        }
    }
}

// MARK: - Forecast Chart

struct ForecastChartCard: View {
    let forecast: [HourlyForecast]

    private var values: [Double] {
        Array(forecast.prefix(24).map { $0.conditions.waveHeight })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next 24h Wave Height")
                .font(.headline)

            LineChartView(values: values, lineColor: .cyan)
                .frame(height: 140)

            if let maxValue = values.max(), let minValue = values.min() {
                Text("Range: \(String(format: "%.1f", minValue))m - \(String(format: "%.1f", maxValue))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LineChartView: View {
    let values: [Double]
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue = values.max() ?? 1
            let minValue = values.min() ?? 0
            let range = max(maxValue - minValue, 0.1)

            Path { path in
                guard values.count > 1 else { return }
                for index in values.indices {
                    let x = width * CGFloat(index) / CGFloat(values.count - 1)
                    let normalized = (values[index] - minValue) / range
                    let y = height - CGFloat(normalized) * height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

struct ConditionCell: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
            
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Warnings View

struct WarningsView: View {
    let warnings: [SafetyWarning]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings, id: \.rawValue) { warning in
                HStack {
                    Image(systemName: warning.icon)
                        .foregroundStyle(Color.from(string: warning.severity.color))
                    
                    Text(warning.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
                .background(Color.from(string: warning.severity.color).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Favorite Locations Section

struct FavoriteLocationsSection: View {
    let locations: [SwimLocation]
    let onSelect: (SwimLocation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favorites")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(locations) { location in
                        Button {
                            onSelect(location)
                        } label: {
                            VStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.cyan)
                                
                                Text(location.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 80)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Loading Card

struct LoadingCardView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading conditions...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Empty State Card

struct EmptyStateCardView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
            
            Text("Ready to check conditions?")
                .font(.headline)
            
            Text("Tap refresh to get current swimming conditions for your location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRefresh) {
                Label("Check Conditions", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding()
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var selectedLevel: SwimmerLevel = .intermediate
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                
                Text("Welcome to OptiSwim")
                    .font(.largeTitle.bold())
                
                Text("Select your swimming experience level to get personalized condition recommendations.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(SwimmerLevel.allCases, id: \.self) { level in
                        Button {
                            selectedLevel = level
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
                                
                                if selectedLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedLevel == level ? Color.cyan : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    if let profile = profiles.first {
                        profile.level = selectedLevel
                        profile.thresholds = ConditionThresholds.defaults(for: selectedLevel)
                        profile.weights = FactorWeights.defaults(for: selectedLevel)
                    }
                    dismiss()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.cyan, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    HomeView(selectedLocation: .constant(nil))
        .modelContainer(for: [SwimLocation.self, UserProfile.self], inMemory: true)
}
