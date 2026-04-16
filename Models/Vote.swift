import Foundation

struct SlotSelection: Codable, Equatable {
    let date: String        // YYYY-MM-DD
    let slotIndex: Int      // 0=Morning, 1=Afternoon, 2=Evening, 3=Night
}

struct Vote: Codable {
    let id: UUID
    let senderId: String        // MSConversation participant UUID
    let senderInitial: String
    let senderColor: String     // hex string
    var dates: [String]         // YYYY-MM-DD strings (for month mode)
    var slots: [SlotSelection]? // for week/days modes
    var updatedAt: Date
}
