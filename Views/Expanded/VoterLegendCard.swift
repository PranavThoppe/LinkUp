import SwiftUI

/// Card showing participants who have voted, with a slot count subtitle.
/// Extracted from the near-identical `voterLegend` computed properties in
/// ExpandedWeekView and ExpandedDaysView.
struct VoterLegendCard: View {
    /// Participants who have submitted any vote for this schedule.
    let participants: [Participant]
    /// Returns the subtitle string shown next to a participant's avatar.
    let subtitleForParticipant: (Participant) -> String

    var body: some View {
        if !participants.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(participants.count) response\(participants.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                ForEach(participants, id: \.id) { participant in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: participant.color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(participant.initial)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        Text(subtitleForParticipant(participant))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
        }
    }
}
