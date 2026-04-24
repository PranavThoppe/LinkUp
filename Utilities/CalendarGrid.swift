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

/// Weekday letter(s) and day-of-month for week/days transcript column headers. Thursday and Saturday use two letters (`Th`, `Sa`); other weekdays use one (`S` … `F`).
func transcriptDayColumnParts(iso: String) -> (weekday: String, day: Int)? {
    guard let (y, m, d) = parseISODate(iso) else { return nil }
    let comps = DateComponents(year: y, month: m + 1, day: d)
    let cal = Calendar(identifier: .gregorian)
    guard let date = cal.date(from: comps) else { return nil }
    let weekday = cal.component(.weekday, from: date)
    let prefix: String
    switch weekday {
    case 1: prefix = "S"
    case 2: prefix = "M"
    case 3: prefix = "T"
    case 4: prefix = "W"
    case 5: prefix = "Th"
    case 6: prefix = "F"
    case 7: prefix = "Sa"
    default: prefix = ""
    }
    return (prefix, d)
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

/// Calendar span for inclusive ISO day endpoints, e.g. `April 21`, `April 21–28`, `April 30 – May 4`.
func monthDayRangeLabel(startIso: String, endIso: String) -> String {
    guard let (sy, sm, sd) = parseISODate(startIso),
          let (ey, em, ed) = parseISODate(endIso) else { return "" }

    let startMonth = monthName(sm, year: sy)

    if startIso == endIso {
        return "\(startMonth) \(sd)"
    }

    if sy == ey && sm == em {
        return "\(startMonth) \(sd)–\(ed)"
    }

    let endMonth = monthName(em, year: ey)

    if sy == ey {
        return "\(startMonth) \(sd) – \(endMonth) \(ed)"
    }

    return "\(startMonth) \(sd), \(sy) – \(endMonth) \(ed), \(ey)"
}

/// Inclusive list of YYYY-MM-DD strings from `startIso` through `endIso` (gregorian).
func dateRangeInclusive(startIso: String, endIso: String) -> [String] {
    guard let (sy, sm, sd) = parseISODate(startIso),
          let (ey, em, ed) = parseISODate(endIso) else { return [] }
    let calendar = Calendar(identifier: .gregorian)
    guard let startDate = calendar.date(from: DateComponents(year: sy, month: sm + 1, day: sd)),
          let endDate = calendar.date(from: DateComponents(year: ey, month: em + 1, day: ed)),
          startDate <= endDate else { return [] }

    var values: [String] = []
    var cursor = startDate
    while cursor <= endDate {
        let y = calendar.component(.year, from: cursor)
        let m = calendar.component(.month, from: cursor) - 1
        let d = calendar.component(.day, from: cursor)
        values.append(toISODate(year: y, month: m, day: d))
        guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
        cursor = next
    }
    return values
}

/// Number of calendar days in `[startIso, endIso]` inclusive. Returns `0` if the range is invalid or empty.
func inclusiveDayCountInRange(startIso: String, endIso: String) -> Int {
    dateRangeInclusive(startIso: startIso, endIso: endIso).count
}

/// Distinct `MonthYear` values touched by the inclusive date range, in chronological order (first day of each month in range).
func uniqueMonthYearsInInclusiveDateRange(startIso: String, endIso: String) -> [MonthYear] {
    let days = dateRangeInclusive(startIso: startIso, endIso: endIso)
    var result: [MonthYear] = []
    var seenKeys = Set<String>()
    for iso in days {
        guard let (y, m, _) = parseISODate(iso) else { continue }
        let key = "\(y)-\(m)"
        if seenKeys.insert(key).inserted {
            result.append(MonthYear(month: m, year: y))
        }
    }
    return result
}

/// Distinct `MonthYear` values for the given ISO date strings, in chronological order.
func uniqueMonthYears(fromSortedIsoDates isos: [String]) -> [MonthYear] {
    var result: [MonthYear] = []
    var seenKeys = Set<String>()
    for iso in isos {
        guard let (y, m, _) = parseISODate(iso) else { continue }
        let key = "\(y)-\(m)"
        if seenKeys.insert(key).inserted {
            result.append(MonthYear(month: m, year: y))
        }
    }
    return result
}

/// Week ranges of this many days or longer are composed as `month` schedules (calendar UX) instead of `week`.
let longWeekRangeInclusiveDayThreshold = 11
/// Days-tab selections with at least this many days convert to month + explicit eligible dates on send.
let longDaysSelectionCountThreshold = 11

/// Returns the ISO date string for today (YYYY-MM-DD) in the local calendar.
func todayISODate() -> String {
    let now = Date()
    let cal = Calendar.current
    let y = cal.component(.year, from: now)
    let m = cal.component(.month, from: now)
    let d = cal.component(.day, from: now)
    return toISODate(year: y, month: m - 1, day: d)
}
