import SwiftUI

struct VoterDots: View {
    let colors: [String]
    let maxVisible: Int

    init(colors: [String], maxVisible: Int = 3) {
        self.colors = colors
        self.maxVisible = maxVisible
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(colors.prefix(maxVisible).enumerated()), id: \.offset) { _, hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 7, height: 7)
            }
            if colors.count > maxVisible {
                Text("+\(colors.count - maxVisible)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.leading, 2)
            }
        }
    }
}
