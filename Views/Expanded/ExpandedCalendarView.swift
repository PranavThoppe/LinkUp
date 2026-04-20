import SwiftUI
import UIKit

struct ExpandedCalendarView: View {
    let payload: MessagePayload
    let selfSenderId: String
    @ObservedObject var voteDraft: MonthVoteDraft
    let onDone: (MessagePayload) -> Void
    let onCollapseToCompact: (() -> Void)?

    @State private var focusedMonthIndex: Int = 0
    @State private var collapseHintOffset: CGFloat = 0
    @State private var isCollapseAnimationRunning = false
    /// Upward drag on toolbar (points); drives footer hint color before collapse completes.
    @State private var collapseToolbarSwipeMagnitude: CGFloat = 0
    /// Footer “swipe down” hint: pulses when user taps the read-only vote grid.
    @State private var swipeHintScale: CGFloat = 1
    @State private var swipeHintBright = false
    @State private var swipeHintAttentionGeneration: UInt = 0

    private let collapseSwipeColorThreshold: CGFloat = 56

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var scheduleMonths: [MonthYear] {
        payload.schedule.months ?? []
    }

    /// Stable key so month list changes clamp the focused index reliably.
    private var scheduleMonthsSignature: String {
        scheduleMonths.map { "\($0.year)-\($0.month)" }.joined(separator: "|")
    }

    private var collapseFooterHintBlueProgress: CGFloat {
        min(max(collapseToolbarSwipeMagnitude / collapseSwipeColorThreshold, 0), 1)
    }

    init(
        payload: MessagePayload,
        selfSenderId: String,
        voteDraft: MonthVoteDraft,
        onDone: @escaping (MessagePayload) -> Void,
        onCollapseToCompact: (() -> Void)? = nil
    ) {
        self.payload = payload
        self.selfSenderId = selfSenderId
        self.voteDraft = voteDraft
        self.onDone = onDone
        self.onCollapseToCompact = onCollapseToCompact
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)
            ScrollView {
                VStack(spacing: 20) {
                    if !scheduleMonths.isEmpty {
                        monthCard(scheduleMonths[focusedMonthIndex])
                    }
                    slotsInsightCard
                }
                .padding(16)
            }
            if !voteDraft.sortedDates.isEmpty {
                Rectangle()
                    .fill(Theme.cardDivider)
                    .frame(height: 0.5)
                ZStack {
                    Text("Swipe down to edit times")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(swipeHintBright ? Color.white : Theme.primaryBlue)
                        .scaleEffect(swipeHintScale)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .offset(y: collapseHintOffset)
                .background(Theme.background)
            }
        }
        .background(Theme.background)
        .onAppear {
            clampFocusedMonthIndex()
            voteDraft.syncFocusedDayWithSelection()
            collapseHintOffset = 0
            isCollapseAnimationRunning = false
            collapseToolbarSwipeMagnitude = 0
        }
        .onChange(of: scheduleMonthsSignature) { _, _ in
            clampFocusedMonthIndex()
        }
        .onChange(of: voteDraft.sortedDates) { _, _ in
            voteDraft.syncFocusedDayWithSelection()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        let stack = HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                if let title = payload.schedule.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                if !scheduleMonths.isEmpty {
                    monthChipStrip
                }
            }
            Spacer()
            Button("Save") {
                onDone(buildUpdatedPayload())
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Theme.primaryBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)

        return Group {
            if onCollapseToCompact != nil {
                stack.highPriorityGesture(toolbarSwipeUpToCompactGesture)
            } else {
                stack
            }
        }
    }

    private func performCollapseToCompact() {
        guard let onCollapseToCompact, !isCollapseAnimationRunning else { return }
        isCollapseAnimationRunning = true
        let duration = 0.28
        withAnimation(.easeInOut(duration: duration)) {
            collapseHintOffset = -48
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onCollapseToCompact()
        }
    }

    /// Swipe up on the toolbar (outside the calendar `ScrollView`) avoids fighting vertical scroll.
    private var toolbarSwipeUpToCompactGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dy = value.translation.height
                let verticalDominant = abs(dy) > abs(value.translation.width) * 1.2
                if dy < 0 && verticalDominant {
                    collapseToolbarSwipeMagnitude = -dy
                } else if dy >= 0 {
                    collapseToolbarSwipeMagnitude = 0
                }
            }
            .onEnded { value in
                let dy = value.translation.height
                let verticalDominant = abs(dy) > abs(value.translation.width) * 1.25
                if dy < -collapseSwipeColorThreshold && verticalDominant {
                    performCollapseToCompact()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    collapseToolbarSwipeMagnitude = 0
                }
            }
    }

    private var monthChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(scheduleMonths.enumerated()), id: \.offset) { index, month in
                    let isSelected = index == focusedMonthIndex
                    Button {
                        focusedMonthIndex = index
                    } label: {
                        Text(chipTitle(for: month))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Theme.primaryBlue : Theme.cardBackground)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chipAccessibilityLabel(month: month, isSelected: isSelected))
                }
            }
        }
    }

    // MARK: - Month card

    private func monthCard(_ month: MonthYear) -> some View {
        let grid = buildMonthGridSunFirst(month: month.month, year: month.year)
        let rows = stride(from: 0, to: grid.count, by: 7)
            .map { Array(grid[$0..<min($0 + 7, grid.count)]) }

        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                        dayCell(cell: rows[rowIndex][colIndex], month: month)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    @ViewBuilder
    private func dayCell(cell: CalendarCell, month: MonthYear) -> some View {
        if cell.inMonth {
            let iso = toISODate(year: month.year, month: month.month, day: cell.day)
            let isSelf = voteDraft.selectedDates.contains(iso)
            let otherColors = otherVoterColorsByDate[iso] ?? []
            let hasOthers = !otherColors.isEmpty
            let baseFill: Color = hasOthers
                ? VoteHeatmap.color(for: otherColors.count, maxCount: maxOtherVotes)
                : Theme.cellDefault
            let fill: Color = (isSelf && !hasOthers) ? Theme.voteGreenHigh : baseFill

            Button {
                voteDraft.toggleDate(iso)
            } label: {
                VStack(spacing: 2) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fill)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if isSelf {
                                    RoundedRectangle(cornerRadius: 8)
                                        .inset(by: 1)
                                        .stroke(Theme.primaryBlue, lineWidth: 4)
                                }
                            }
                        Text(verbatim: "\(cell.day)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VoterDots(colors: otherColors, maxVisible: 3)
                        .frame(height: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dayCellAccessibilityLabel(day: cell.day, isSelected: isSelf))
            .accessibilityAddTraits(isSelf ? .isSelected : [])
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
    }

    private var slotsInsightCard: some View {
        Group {
            if !voteDraft.sortedDates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time slots (all votes)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    Picker("Day", selection: $voteDraft.focusedDayIso) {
                        ForEach(voteDraft.sortedDates, id: \.self) { iso in
                            Text(slotPickerTitle(iso)).tag(iso)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VoteToggleGrid(
                        dayColumns: focusedLegendDayColumns,
                        slotLabels: slotLabels,
                        selectedSlots: Binding(
                            get: { voteDraft.selectedSlotKeys },
                            set: { _ in }
                        ),
                        otherVoterSlots: legendOtherVoterSlotsByKey,
                        isInteractive: false,
                        orientation: .slotsOnXAxis,
                        onBlockedInteraction: triggerSwipeHintAttention
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.cardBackground)
                .cornerRadius(16)
            }
        }
    }

    /// Haptic + double pulse on the footer hint when the read-only grid is tapped.
    private func triggerSwipeHintAttention() {
        swipeHintAttentionGeneration += 1
        let generation = swipeHintAttentionGeneration

        func applyPulse(emphasized: Bool) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                swipeHintScale = emphasized ? 1.1 : 1.0
            }
            withAnimation(.easeInOut(duration: 0.12)) {
                swipeHintBright = emphasized
            }
        }

        Task { @MainActor in
            guard generation == swipeHintAttentionGeneration else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            applyPulse(emphasized: true)
            try? await Task.sleep(nanoseconds: 135_000_000)
            guard generation == swipeHintAttentionGeneration else { return }
            applyPulse(emphasized: false)
            try? await Task.sleep(nanoseconds: 165_000_000)
            guard generation == swipeHintAttentionGeneration else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            applyPulse(emphasized: true)
            try? await Task.sleep(nanoseconds: 135_000_000)
            guard generation == swipeHintAttentionGeneration else { return }
            applyPulse(emphasized: false)
        }
    }

    // MARK: - Computed
    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    private var otherVoterColorsByDate: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            for date in vote.dates {
                map[date, default: []].append(vote.senderColor)
            }
        }
        return map
    }

    private var maxOtherVotes: Int {
        max(otherVoterColorsByDate.values.map(\.count).max() ?? 0, 1)
    }

    /// Other participants' slot votes for the focused legend day (excludes self so heatmap + ring match the calendar).
    private var legendOtherVoterSlotsByKey: [String: [String]] {
        guard !voteDraft.focusedDayIso.isEmpty else { return [:] }
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            for slot in vote.slots ?? [] where slot.date == voteDraft.focusedDayIso {
                let key = makeSlotKey(date: slot.date, slotIndex: slot.slotIndex)
                map[key, default: []].append(vote.senderColor)
            }
        }
        return map
    }

    private func clampFocusedMonthIndex() {
        let count = scheduleMonths.count
        guard count > 0 else {
            focusedMonthIndex = 0
            return
        }
        focusedMonthIndex = min(max(0, focusedMonthIndex), count - 1)
    }

    private var focusedLegendDayColumns: [String] {
        voteDraft.focusedDayIso.isEmpty ? [] : [voteDraft.focusedDayIso]
    }

    private func chipTitle(for month: MonthYear) -> String {
        let short = shortMonthName(month.month)
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        if month.year == currentYear {
            return short
        }
        return "\(short) \(month.year)"
    }

    private func chipAccessibilityLabel(month: MonthYear, isSelected: Bool) -> String {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let base = month.year == currentYear
            ? monthName(month.month)
            : "\(monthName(month.month)) \(month.year)"
        return isSelected ? "\(base), selected" : base
    }

    private func dayCellAccessibilityLabel(day: Int, isSelected: Bool) -> String {
        let n = "\(day)"
        return isSelected ? "\(n), selected, your availability" : n
    }

    private func slotPickerTitle(_ iso: String) -> String {
        guard let parts = transcriptDayColumnParts(iso: iso) else { return iso }
        return "\(parts.weekday) \(parts.day) · \(monthNameFromIso(iso))"
    }

    private func monthNameFromIso(_ iso: String) -> String {
        guard let (_, m, _) = parseISODate(iso) else { return "" }
        return monthName(m)
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

    // MARK: - Build updated payload

    private func buildUpdatedPayload() -> MessagePayload {
        buildUpdatedMonthPayload(
            payload: payload,
            selfSenderId: selfSenderId,
            selectedDates: voteDraft.selectedDates,
            selectedSlotKeys: voteDraft.selectedSlotKeys
        )
    }
}
