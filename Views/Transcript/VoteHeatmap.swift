import SwiftUI

struct VoteHeatmap {
    /// Returns a color linearly interpolated between #2A2F2A (0 votes) and #34C759 (max votes).
    /// Returns Color.clear when count is 0 so unvoted cells have a transparent background.
    static func color(for count: Int, maxCount: Int) -> Color {
        guard count > 0, maxCount > 0 else { return Color.clear }
        let t = min(max(Double(count) / Double(maxCount), 0), 1)
        // RGB lerp: #2A2F2A → #34C759
        let r = (0x2A + t * Double(0x34 - 0x2A)) / 255
        let g = (0x2F + t * Double(0xC7 - 0x2F)) / 255
        let b = (0x2A + t * Double(0x59 - 0x2A)) / 255
        return Color(red: r, green: g, blue: b)
    }
}
