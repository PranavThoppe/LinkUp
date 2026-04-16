import Foundation

struct MonthYear: Codable, Equatable, Hashable {
    let month: Int  // 0-indexed (Jan = 0)
    let year: Int
}

struct DateRange: Codable, Equatable {
    let startIso: String    // YYYY-MM-DD
    let endIso: String      // YYYY-MM-DD
}

struct Schedule: Codable {
    let id: UUID
    let creatorId: String
    let mode: ScheduleMode
    var title: String?

    var months: [MonthYear]?
    var weekRange: DateRange?
    var specificDates: [String]?    // YYYY-MM-DD strings

    let createdAt: Date
    var updatedAt: Date
    var isActive: Bool
}
