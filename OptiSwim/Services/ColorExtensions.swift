import SwiftUI

extension Color {
    static func from(string: String) -> Color {
        switch string.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "cyan": return .cyan
        case "pink": return .pink
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .primary
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
