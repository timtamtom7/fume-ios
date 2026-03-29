import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Fume Colors (macOS version)

struct FumeColors {
    static let background = Color(hex: "0a0a0b")
    static let surface = Color(hex: "141416")
    static let surfaceRaised = Color(hex: "1c1c1f")
    static let glassOverlay = Color(hex: "1e1e20").opacity(0.85)
    static let accent = Color(hex: "f59e0b")
    static let accentDim = Color(hex: "d97706")
    static let textPrimary = Color(hex: "f4f4f5")
    static let textSecondary = Color(hex: "a1a1aa")
    static let sourceHighlight = Color(hex: "f59e0b").opacity(0.15)
    static let border = Color(hex: "2a2a2e")
    static let divider = Color(hex: "27272a")
}

// MARK: - Fume Error

enum FumeError: Error, Identifiable, Equatable {
    case aiQueryFailed
    case storageLimitReached
    case syncFailed
    case importFailed

    var id: String {
        switch self {
        case .aiQueryFailed: return "aiQueryFailed"
        case .storageLimitReached: return "storageLimitReached"
        case .syncFailed: return "syncFailed"
        case .importFailed: return "importFailed"
        }
    }

    var title: String {
        switch self {
        case .aiQueryFailed: return "AI Query Failed"
        case .storageLimitReached: return "Storage Limit Reached"
        case .syncFailed: return "Sync Failed"
        case .importFailed: return "Import Failed"
        }
    }

    var message: String {
        switch self {
        case .aiQueryFailed: return "Failed to process your query. Please try again."
        case .storageLimitReached: return "You've reached the free tier limit of 50 sources. Upgrade to continue adding more."
        case .syncFailed: return "Failed to sync with iCloud. Your data is saved locally."
        case .importFailed: return "Failed to import the selected files."
        }
    }
}
