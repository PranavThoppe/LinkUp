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

struct Vote: Codable, Equatable {
    let id: UUID
    let senderId: String        // MSConversation participant UUID
    let senderInitial: String
    let senderColor: String     // hex string
    var dates: [String]         // YYYY-MM-DD strings (for month mode)
    var slots: [SlotSelection]? // for week/days modes
    var hours: [HourSelection]? // optional hour-level picks within slots
    var updatedAt: Date
    /// Per-sender monotonic counter; used by the mirror RPC so concurrent voters do not clobber each other.
    var voteRevision: Int

    init(
        id: UUID,
        senderId: String,
        senderInitial: String,
        senderColor: String,
        dates: [String],
        slots: [SlotSelection]?,
        hours: [HourSelection]? = nil,
        updatedAt: Date,
        voteRevision: Int = 0
    ) {
        self.id = id
        self.senderId = senderId
        self.senderInitial = senderInitial
        self.senderColor = senderColor
        self.dates = dates
        self.slots = slots
        self.hours = hours
        self.updatedAt = updatedAt
        self.voteRevision = voteRevision
    }

    enum CodingKeys: String, CodingKey {
        case id, senderId, senderInitial, senderColor, dates, slots, hours, updatedAt, voteRevision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        senderId = try c.decode(String.self, forKey: .senderId)
        senderInitial = try c.decode(String.self, forKey: .senderInitial)
        senderColor = try c.decode(String.self, forKey: .senderColor)
        dates = try c.decode([String].self, forKey: .dates)
        slots = try c.decodeIfPresent([SlotSelection].self, forKey: .slots)
        hours = try c.decodeIfPresent([HourSelection].self, forKey: .hours)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        voteRevision = try c.decodeIfPresent(Int.self, forKey: .voteRevision) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(senderId, forKey: .senderId)
        try c.encode(senderInitial, forKey: .senderInitial)
        try c.encode(senderColor, forKey: .senderColor)
        try c.encode(dates, forKey: .dates)
        try c.encodeIfPresent(slots, forKey: .slots)
        try c.encodeIfPresent(hours, forKey: .hours)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(voteRevision, forKey: .voteRevision)
    }
}
