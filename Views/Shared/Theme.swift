import SwiftUI

enum Theme {
    // MARK: - Backgrounds
    static let background = Color(hex: "#000000")
    static let cardBackground = Color(hex: "#1C1C1E")
    static let cardBorder = Color(hex: "#38383A")
    static let composerBackground = Color(hex: "#1C1C1E")

    // MARK: - Text
    static let textPrimary = Color(hex: "#ECEDEE")
    static let textSecondary = Color(hex: "#6E6E73")

    // MARK: - Accent
    static let primaryBlue = Color(hex: "#0A84FF")
    static let voteGreenLow = Color(hex: "#2A2F2A")
    static let voteGreenHigh = Color(hex: "#34C759")
    static let statusOrange = Color(hex: "#FF9F0A")
    static let statusGreen = Color(hex: "#34C759")

    // MARK: - Cell states
    static let cellDefault = Color(hex: "#3A3A3C")

    // MARK: - Participant palette (matches Participant.palette)
    static let participantColors: [Color] = [
        Color(hex: "#FF6B9D"),
        Color(hex: "#34C759"),
        Color(hex: "#007AFF"),
        Color(hex: "#FF9F0A"),
        Color(hex: "#BF5AF2"),
        Color(hex: "#FF375F"),
    ]
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
