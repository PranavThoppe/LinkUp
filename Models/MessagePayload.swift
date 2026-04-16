import Foundation

struct MessagePayload: Codable {
    /// Schema version. Increment on any breaking change.
    /// Clients that receive a version higher than `currentVersion` show an "update app" fallback.
    let version: Int
    let schedule: Schedule
    var votes: [Vote]
    var participants: [Participant]
    /// Monotonically incremented on every write. Used as a last-write-wins tiebreaker.
    var revision: Int
    /// senderId of the participant who last updated this payload.
    var lastWriterId: String

    static let currentVersion = 1
}
