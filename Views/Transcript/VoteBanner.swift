import SwiftUI

struct VoteBanner: View {
    let hasVoted: Bool

    var body: some View {
        HStack {
            Spacer()
            Text(hasVoted ? "YOU VOTED  ✓" : "YOUR TURN  →")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(hasVoted ? Color(hex: "#34C759") : Color(hex: "#FF9F0A"))
                .tracking(0.5)
            Spacer()
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.65))
    }
}
