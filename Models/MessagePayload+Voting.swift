import Foundation

extension MessagePayload {
    /// Whether `participantId` has submitted vote selections for this schedule mode.
    func hasVote(from participantId: String) -> Bool {
        votes.contains { vote in
            guard vote.senderId == participantId else { return false }
            switch schedule.mode {
            case .month:
                return !vote.dates.isEmpty
            case .week, .days:
                return !(vote.slots ?? []).isEmpty || !vote.dates.isEmpty
            }
        }
    }
}
