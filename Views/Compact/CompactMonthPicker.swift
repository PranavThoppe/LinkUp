import SwiftUI

struct CompactMonthPicker: View {
    @Binding var selectedMonths: [MonthYear]
    let isScrollable: Bool

    private let months: [MonthYear] = buildUpcomingMonths(count: 24)
    private var visibleMonths: [MonthYear] { isScrollable ? months : Array(months.prefix(6)) }

    private var selectedSet: Set<String> {
        Set(selectedMonths.map { monthKey($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick Months")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.voteGreenHigh)

            Text(selectedMonths.isEmpty ? "Tap months to include" : "\(selectedMonths.count) selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Group {
                if isScrollable {
                    ScrollView(.vertical, showsIndicators: false) {
                        monthGrid(months: visibleMonths)
                    }
                } else {
                    monthGrid(months: visibleMonths)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func monthGrid(months: [MonthYear]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 8
        ) {
            ForEach(months, id: \.self) { item in
                monthCell(item)
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func monthCell(_ item: MonthYear) -> some View {
        let key = monthKey(item)
        let isSelected = selectedSet.contains(key)

        Button {
            toggleMonth(item)
        } label: {
            VStack(spacing: 2) {
                Text(shortMonthName(item.month))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(verbatim: String(item.year))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#E7FFE8") : Color(hex: "#8E8E93"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(isSelected ? Theme.voteGreenHigh : Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func toggleMonth(_ item: MonthYear) {
        let key = monthKey(item)
        if selectedSet.contains(key) {
            selectedMonths.removeAll { monthKey($0) == key }
        } else {
            selectedMonths.append(item)
            selectedMonths.sort {
                if $0.year != $1.year { return $0.year < $1.year }
                return $0.month < $1.month
            }
        }
    }
}

// MARK: - Helpers

private func monthKey(_ m: MonthYear) -> String {
    String(format: "%04d-%02d", m.year, m.month + 1)
}

private func shortMonthName(_ month: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM"
    var comps = DateComponents()
    comps.month = month + 1
    comps.year = 2000
    comps.day = 1
    let date = Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    return formatter.string(from: date)
}

private func buildUpcomingMonths(count: Int) -> [MonthYear] {
    let now = Date()
    let cal = Calendar(identifier: .gregorian)
    let startMonth = cal.component(.month, from: now) - 1  // 0-indexed
    let startYear = cal.component(.year, from: now)
    return (0..<count).map { i in
        let abs = startMonth + i
        return MonthYear(month: abs % 12, year: startYear + abs / 12)
    }
}
