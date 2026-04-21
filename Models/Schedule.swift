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
    /// For `.month` only: inclusive ISO range where voting is allowed; other days in the month grid are visual-only.
    /// Ignored when `eligibleSpecificDates` is non-empty (explicit allow-list wins).
    var eligibleDateRange: DateRange?
    /// For `.month` only: exact ISO dates that are in the poll (non-contiguous); when set, overrides `eligibleDateRange`.
    var eligibleSpecificDates: [String]?

    let createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    /// Returns a copy with `updatedAt` set to now — used when writing a new vote message.
    func stampedNow() -> Schedule {
        Schedule(
            id: id, creatorId: creatorId, mode: mode, title: title,
            months: months, weekRange: weekRange, specificDates: specificDates,
            eligibleDateRange: eligibleDateRange,
            eligibleSpecificDates: eligibleSpecificDates,
            createdAt: createdAt, updatedAt: Date(), isActive: isActive
        )
    }
}

extension Schedule {
    /// ISO days in the poll for restricted `.month` schedules; `nil` means every in-grid day is allowed.
    var eligiblePollDates: Set<String>? {
        guard mode == .month else { return nil }
        if let explicit = eligibleSpecificDates, !explicit.isEmpty {
            return Set(explicit)
        }
        if let range = eligibleDateRange {
            let days = dateRangeInclusive(startIso: range.startIso, endIso: range.endIso)
            return days.isEmpty ? nil : Set(days)
        }
        return nil
    }
}
