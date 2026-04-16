import SwiftUI

private let dowLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

struct CompactWeekPicker: View {
    @Binding var startIso: String?
    @Binding var endIso: String?
    let isScrollable: Bool

    private let months: [MonthYear] = buildPickerMonths(count: 16)
    /// Compact shows one month so tab bar + Send stay visible; expanded lists all with scrolling.
    private var visibleMonths: [MonthYear] { isScrollable ? months : Array(months.prefix(1)) }
    private let todayIso: String = todayISODate()

    private var dayRowHeight: CGFloat { isScrollable ? 36 : 28 }
    private var dayLabelWidth: CGFloat { isScrollable ? 34 : 28 }
    private var dayLabelHeight: CGFloat { isScrollable ? 30 : 22 }
    private var dayFontSize: CGFloat { isScrollable ? 12 : 11 }
    private var dayCornerRadius: CGFloat { isScrollable ? 8 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick Date Range")
                .font(.system(size: isScrollable ? 18 : 16, weight: .bold))
                .foregroundColor(Theme.voteGreenHigh)

            // Day-of-week header
            HStack(spacing: 0) {
                ForEach(dowLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: isScrollable ? 11 : 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, isScrollable ? 12 : 8)
            .padding(.bottom, isScrollable ? 6 : 4)

            Group {
                if isScrollable {
                    ScrollView(.vertical, showsIndicators: false) {
                        monthList(months: visibleMonths)
                    }
                } else {
                    monthList(months: visibleMonths)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func monthList(months: [MonthYear]) -> some View {
        VStack(spacing: isScrollable ? 16 : 10) {
            ForEach(months, id: \.self) { month in
                monthBlock(month)
            }
        }
        .padding(.bottom, isScrollable ? 20 : 8)
    }

    @ViewBuilder
    private func monthBlock(_ month: MonthYear) -> some View {
        let grid = buildMonthGridSunFirst(month: month.month, year: month.year)
        let rows = stride(from: 0, to: grid.count, by: 7).map { Array(grid[$0..<min($0 + 7, grid.count)]) }

        VStack(alignment: .leading, spacing: 0) {
            Text("\(monthName(month.month)) \(String(month.year))")
                .font(.system(size: isScrollable ? 14 : 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, isScrollable ? 6 : 4)

            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<rows[rowIdx].count, id: \.self) { colIdx in
                        dayCell(cell: rows[rowIdx][colIdx], month: month)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(cell: CalendarCell, month: MonthYear) -> some View {
        if !cell.inMonth {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: dayRowHeight)
        } else {
            let iso = toISODate(year: month.year, month: month.month, day: cell.day)
            let isPast = iso < todayIso
            let isStart = startIso == iso
            let isEnd = endIso == iso
            let isEndpoint = isStart || isEnd
            let isInRange: Bool = {
                guard let s = startIso, let e = endIso else { return false }
                return iso >= s && iso <= e
            }()

            Button {
                if !isPast { handleTap(iso) }
            } label: {
                Text("\(cell.day)")
                    .font(.system(size: dayFontSize, weight: .heavy))
                    .foregroundColor(isPast ? Color.white.opacity(0.3) : .white)
                    .frame(width: dayLabelWidth, height: dayLabelHeight)
                    .background(
                        Group {
                            if isEndpoint {
                                Theme.voteGreenHigh
                            } else if isInRange {
                                Theme.voteGreenHigh.opacity(0.22)
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .cornerRadius(dayCornerRadius)
            }
            .buttonStyle(.plain)
            .disabled(isPast)
            .frame(maxWidth: .infinity)
            .frame(height: dayRowHeight)
        }
    }

    private func handleTap(_ iso: String) {
        // Full range → tap endpoints to shrink, any other tap → restart
        if let s = startIso, let e = endIso {
            if iso == s {
                if s == e {
                    startIso = nil; endIso = nil
                } else {
                    let next = addDays(to: s, days: 1)
                    if next > e { startIso = nil; endIso = nil }
                    else { startIso = next }
                }
            } else if iso == e {
                let next = addDays(to: e, days: -1)
                if next < s { startIso = nil; endIso = nil }
                else { endIso = next }
            } else {
                startIso = iso; endIso = nil
            }
            return
        }

        if startIso == nil {
            startIso = iso
            return
        }

        // startIso set, endIso nil
        if iso < startIso! {
            endIso = startIso
            startIso = iso
        } else {
            endIso = iso
        }
    }

    private func addDays(to iso: String, days: Int) -> String {
        guard let (y, m, d) = parseISODate(iso) else { return iso }
        let comps = DateComponents(year: y, month: m + 1, day: d)
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps),
              let newDate = cal.date(byAdding: .day, value: days, to: date) else { return iso }
        let ny = cal.component(.year, from: newDate)
        let nm = cal.component(.month, from: newDate) - 1
        let nd = cal.component(.day, from: newDate)
        return toISODate(year: ny, month: nm, day: nd)
    }
}

private func buildPickerMonths(count: Int) -> [MonthYear] {
    let now = Date()
    let cal = Calendar(identifier: .gregorian)
    let startMonth = cal.component(.month, from: now) - 1
    let startYear = cal.component(.year, from: now)
    return (0..<count).map { i in
        let abs = startMonth + i
        return MonthYear(month: abs % 12, year: startYear + abs / 12)
    }
}
