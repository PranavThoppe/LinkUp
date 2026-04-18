import SwiftUI

/// Centered filled CTA for transcript snapshots (static image).
struct TranscriptTapCallout: View {
    let hasVoted: Bool

    var body: some View {
        Text(hasVoted ? "TAP TO VIEW" : "TAP TO VOTE")
            .font(.system(size: 17, weight: .black))
            .tracking(1.0)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Theme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
            .allowsHitTesting(false)
    }
}
