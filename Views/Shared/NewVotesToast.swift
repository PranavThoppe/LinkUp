import SwiftUI

/// A non-intrusive banner that slides in from the top and auto-fades after a short delay.
/// Shown when new votes arrive from other participants while the local user has unsaved edits.
struct NewVotesToast: View {
    @State private var visible = true

    var body: some View {
        if visible {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primaryBlue)
                Text("New votes received")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Theme.cardBackground)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        visible = false
                    }
                }
            }
        }
    }
}
