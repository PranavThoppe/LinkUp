import Foundation

struct SlotSelection: Codable, Equatable {
    let date: String        // YYYY-MM-DD
    let slotIndex: Int      // 0=Morning, 1=Afternoon, 2=Evening, 3=Night
}

/// A specific hour within a slot that the user marked as available.
/// Stored alongside `SlotSelection` entries; the two are independent.
struct HourSelection: Codable, Equatable {
    let date: String        // YYYY-MM-DD
    let slotIndex: Int      // 0=Morning, 1=Afternoon, 2=Evening, 3=Night
    let hour: Int           // 0–23 (wall-clock hour)
}

struct Vote: Codable {
    let id: UUID
    let senderId: String        // MSConversation participant UUID
    let senderInitial: String
    let senderColor: String     // hex string
    var dates: [String]         // YYYY-MM-DD strings (for month mode)
    var slots: [SlotSelection]? // for week/days modes
    var hours: [HourSelection]? // optional hour-level picks within slots
    var updatedAt: Date
}
