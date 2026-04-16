import Foundation

struct CalendarCell {
    let day: Int
    let inMonth: Bool
}

/// Builds a flat 42-cell (6 rows × 7 cols) Sunday-first grid for the given month.
func buildMonthGridSunFirst(month: Int, year: Int) -> [CalendarCell] {
    var components = DateComponents()
    components.year = year
    components.month = month + 1  // Calendar.month is 1-indexed
    components.day = 1

    let calendar = Calendar(identifier: .gregorian)
    guard let firstDay = calendar.date(from: components),
          let range = calendar.range(of: .day, in: .month, for: firstDay) else {
        return []
    }

    let daysInMonth = range.count
    // weekday: 1=Sunday ... 7=Saturday
    let firstWeekday = calendar.component(.weekday, from: firstDay) - 1 // 0-indexed

    var cells: [CalendarCell] = []

    // Leading empty cells from previous month
    let prevMonthComponents = DateComponents(year: year, month: month, day: 1)  // month is 0-indexed → Calendar month = month (which is prev)
    if let prevFirst = calendar.date(from: prevMonthComponents),
       let prevRange = calendar.range(of: .day, in: .month, for: prevFirst) {
        let prevDaysInMonth = prevRange.count
        for i in (0..<firstWeekday).reversed() {
            cells.append(CalendarCell(day: prevDaysInMonth - i, inMonth: false))
        }
    } else {
        for _ in 0..<firstWeekday {
            cells.append(CalendarCell(day: 0, inMonth: false))
        }
    }

    // Current month days
    for day in 1...daysInMonth {
        cells.append(CalendarCell(day: day, inMonth: true))
    }

    // Trailing cells to fill remaining slots
    let remainder = cells.count % 7
    if remainder != 0 {
        let trailing = 7 - remainder
        for day in 1...trailing {
            cells.append(CalendarCell(day: day, inMonth: false))
        }
    }

    return cells
}

/// Returns a YYYY-MM-DD string for the given year/month(0-indexed)/day.
func toISODate(year: Int, month: Int, day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month + 1, day)
}

/// Parses a YYYY-MM-DD string into (year, month0indexed, day) components.
/// Returns nil if the string is malformed.
func parseISODate(_ iso: String) -> (year: Int, month: Int, day: Int)? {
    let parts = iso.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]),
          let m = Int(parts[1]),
          let d = Int(parts[2]) else { return nil }
    return (y, m - 1, d)
}

/// Full month name (e.g. "April") for a 0-indexed month.
func monthName(_ month: Int, year: Int? = nil) -> String {
    var comps = DateComponents()
    comps.month = month + 1
    comps.year = year ?? 2000
    comps.day = 1
    let cal = Calendar(identifier: .gregorian)
    guard let date = cal.date(from: comps) else { return "" }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM"
    return formatter.string(from: date)
}

/// Returns the ISO date string for today (YYYY-MM-DD) in the local calendar.
func todayISODate() -> String {
    let now = Date()
    let cal = Calendar.current
    let y = cal.component(.year, from: now)
    let m = cal.component(.month, from: now)
    let d = cal.component(.day, from: now)
    return toISODate(year: y, month: m - 1, day: d)
}
