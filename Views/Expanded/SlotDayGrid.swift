import SwiftUI

/// Interactive slot grid for week and days modes.
///
/// Layout (rows top-to-bottom):
///   1. DOW abbreviations (S M T W Th F Sa) — tapping a column toggles whole-day.
///   2. Date number badges — tapping toggles whole-day; today highlighted blue; self-pick gets color border.
///   3. Four slot rows (Morn / Aftn / Eve / Night) — heatmap fill + self-color border when picked.
///   4. Optional voter-dots row showing which other participants are available each day.
///
/// `colWidth` drives the column sizing:
///   - `nil` → each column expands proportionally (flex-1, good for ≤5 days filling the card width).
///   - fixed `CGFloat` → each column has that exact width; the parent is expected to wrap in a
///     horizontal `ScrollView` for wide day sets.
///
/// This view is the Swift analogue of MVP's `SlotGrid` component in WeekCard.tsx / DaysCard.tsx.
struct SlotDayGrid: View {
    let days: [String]
    var slotLabels: [String] = ["Morn", "Aftn", "Eve", "Night"]
    let selfWholeDays: Set<String>
    let selfSlotKeys: Set<String>
    /// Per-slot voter colors from OTHER participants (excluding self), keyed `"date#slotIndex"`.
    let otherVoterSlotsByKey: [String: [String]]
    /// Other-participant colors per ISO date, used for the voter-dots row.
    let otherVoterDaysByIso: [String: [String]]
    var showVoterDots: Bool = false
    /// Fixed pixel width per day column. `nil` = flex-1.
    var colWidth: CGFloat? = nil
    var isInteractive: Bool = true
    var onToggleWholeDay: ((String) -> Void)? = nil
    var onToggleSlot: ((String, Int) -> Void)? = nil

    private let labelWidth: CGFloat = 40
    private let todayIso: String = todayISODate()
    private let cellHeight: CGFloat = 44

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            dowRow
            dateRow
            ForEach(0..<slotLabels.count, id: \.self) { slotIdx in
                slotRow(slotIdx: slotIdx)
            }
            if showVoterDots {
                voterDotsRow
            }
        }
    }

    // MARK: - DOW row

    private var dowRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth)
            ForEach(days, id: \.self) { iso in
                let abbr = dowAbbreviation(iso: iso)
                let isToday = iso == todayIso
                let inner = Text(abbr)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isToday ? Theme.primaryBlue : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                if isInteractive, let onToggleWholeDay {
                    Button { onToggleWholeDay(iso) } label: { inner }
                        .buttonStyle(.plain)
                        .dayColFrame(colWidth: colWidth)
                } else {
                    inner.dayColFrame(colWidth: colWidth)
                }
            }
        }
    }

    // MARK: - Date badge row

    private var dateRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth)
            ForEach(days, id: \.self) { iso in
                let dayNum = dayNumber(from: iso)
                let isToday = iso == todayIso
                let hasAny = hasSelfPick(on: iso)

                let badge = ZStack {
                    Circle()
                        .fill(isToday ? Theme.primaryBlue : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay {
                            if hasAny && !isToday {
                                Circle()
                                    .inset(by: 1)
                                    .stroke(Theme.primaryBlue, lineWidth: 2)
                            }
                        }
                    Text(verbatim: "\(dayNum)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)

                if isInteractive, let onToggleWholeDay {
                    Button { onToggleWholeDay(iso) } label: { badge }
                        .buttonStyle(.plain)
                        .dayColFrame(colWidth: colWidth)
                } else {
                    badge.dayColFrame(colWidth: colWidth)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Slot row

    private func slotRow(slotIdx: Int) -> some View {
        HStack(spacing: 0) {
            Text(slotLabels[slotIdx])
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 6)

            ForEach(days, id: \.self) { iso in
                slotCell(iso: iso, slotIdx: slotIdx)
            }
        }
    }

    @ViewBuilder
    private func slotCell(iso: String, slotIdx: Int) -> some View {
        let key = "\(iso)#\(slotIdx)"
        let otherColors = otherVoterSlotsByKey[key] ?? []
        let maxOther = max(otherVoterSlotsByKey.values.map(\.count).max() ?? 0, 1)
        let isSelf = selfCoversSlot(iso: iso, slotIdx: slotIdx)

        let fill: Color = otherColors.isEmpty
            ? (isSelf ? Theme.voteGreenHigh : Theme.cellDefault)
            : VoteHeatmap.color(for: otherColors.count, maxCount: maxOther)

        let cellView = RoundedRectangle(cornerRadius: 8)
            .fill(fill)
            .overlay {
                if isSelf {
                    RoundedRectangle(cornerRadius: 8)
                        .inset(by: 1.5)
                        .stroke(Theme.primaryBlue, lineWidth: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .padding(.horizontal, 2)

        if isInteractive, let onToggleSlot {
            Button { onToggleSlot(iso, slotIdx) } label: { cellView }
                .buttonStyle(.plain)
                .dayColFrame(colWidth: colWidth)
        } else {
            cellView.dayColFrame(colWidth: colWidth)
        }
    }

    // MARK: - Voter dots row

    private var voterDotsRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth)
            ForEach(days, id: \.self) { iso in
                let colors = otherVoterDaysByIso[iso] ?? []
                VoterDots(colors: colors, maxVisible: 3)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .dayColFrame(colWidth: colWidth)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Pure helpers

    private func hasSelfPick(on iso: String) -> Bool {
        if selfWholeDays.contains(iso) { return true }
        return selfSlotKeys.contains { $0.hasPrefix("\(iso)#") }
    }

    private func selfCoversSlot(iso: String, slotIdx: Int) -> Bool {
        if selfWholeDays.contains(iso) { return true }
        return selfSlotKeys.contains("\(iso)#\(slotIdx)")
    }

    private func dowAbbreviation(iso: String) -> String {
        guard let (y, m, d) = parseISODate(iso) else { return "" }
        let comps = DateComponents(year: y, month: m + 1, day: d)
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return "" }
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "Th"
        case 6: return "F"
        case 7: return "Sa"
        default: return ""
        }
    }

    private func dayNumber(from iso: String) -> Int {
        guard let (_, _, d) = parseISODate(iso) else { return 0 }
        return d
    }
}

// MARK: - Layout helper

private extension View {
    /// Applies either a fixed-width frame or a flex-fill frame based on `colWidth`.
    @ViewBuilder
    func dayColFrame(colWidth: CGFloat?) -> some View {
        if let w = colWidth {
            self.frame(width: w)
        } else {
            self.frame(maxWidth: .infinity)
        }
    }
}
