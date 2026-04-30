import SwiftUI

/// Hour-level time picker shown below the slot grid in week and days modes.
///
/// For the focused day, shows all four slot windows (Morn → Night) so the user can add
/// optional hour detail in any slot without changing main grid slot votes.
/// Navigated with chevrons (mirrors the day-window pattern in ExpandedDaysView).
struct SlotHourPickerCard: View {
    let dayOptions: [String]
    @Binding var focusedDayIso: String
    let selectedSlotKeys: Set<String>
    @Binding var selectedHourKeys: Set<String>
    /// Per-hour voter colors from OTHER participants, keyed `"date#slotIndex#hour"`.
    let otherVoterHoursByKey: [String: [String]]
    let slotLabels: [String]
    /// Called when the user finishes a drag gesture.
    /// Args: (slotIndex, startHour, endHour, wasSelectedAtDragStart)
    let onToggleRange: (_ slotIndex: Int, _ startHour: Int, _ endHour: Int, _ initiallySelected: Bool) -> Void

    @State private var focusedSlotPosition: Int = 0
    @State private var dragStartHour: Int? = nil
    @State private var dragCurrentHour: Int? = nil
    @State private var dragInitiallySelected: Bool = false

    // Wall-clock hours included in each slot, in order.
    static let slotHours: [[Int]] = [
        Array(6...11),   // Morn:  6 am – 12 pm
        Array(12...16),  // Aftn: 12 pm –  5 pm
        Array(17...20),  // Eve:   5 pm –  9 pm
        Array(21...23),  // Night: 9 pm – 12 am
    ]

    var body: some View {
        if !dayOptions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Day", selection: $focusedDayIso) {
                    ForEach(dayOptions, id: \.self) { iso in
                        Text(dayLabel(iso)).tag(iso)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                if slotWindows.count > 1 {
                    chevronNavRow
                } else {
                    slotTitleLabel(for: currentSlotIndex, centered: false)
                }

                hourBar(for: currentSlotIndex)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onChange(of: slotWindows) { _, newWindows in
                focusedSlotPosition = min(focusedSlotPosition, max(0, newWindows.count - 1))
                syncFocusedSlotWithSelection()
                resetDrag()
            }
            .onChange(of: focusedDayIso) { _, _ in
                syncFocusedSlotWithSelection()
                resetDrag()
            }
            .onChange(of: selectedSlotKeys) { oldKeys, newKeys in
                // Jump to a slot that was just toggled ON for the focused day.
                // Using a diff avoids relying on non-deterministic Set iteration order.
                let added = newKeys.subtracting(oldKeys)
                if let addedKey = added.first(where: { $0.hasPrefix("\(focusedDayIso)#") }),
                   let slot = parseSlotKey(addedKey),
                   let pos = slotWindows.firstIndex(of: slot.slotIndex) {
                    focusedSlotPosition = pos
                }
                focusedSlotPosition = min(focusedSlotPosition, max(0, slotWindows.count - 1))
                resetDrag()
            }
            .onAppear {
                clampFocusedDayToOptions()
                syncFocusedSlotWithSelection()
            }
            .onChange(of: dayOptions) { _, _ in
                clampFocusedDayToOptions()
                syncFocusedSlotWithSelection()
                resetDrag()
            }
        }
    }

    // MARK: - Chevron nav

    private var chevronNavRow: some View {
        HStack(spacing: 12) {
            Button {
                focusedSlotPosition -= 1
                resetDrag()
            } label: {
                Image(systemName: canGoPrevious ? "chevron.left.circle.fill" : "chevron.left.circle")
                    .font(.system(size: 22))
                    .foregroundColor(canGoPrevious ? Theme.primaryBlue : Theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canGoPrevious)

            slotTitleLabel(for: currentSlotIndex, centered: true)
                .frame(maxWidth: .infinity)

            Button {
                focusedSlotPosition += 1
                resetDrag()
            } label: {
                Image(systemName: canGoNext ? "chevron.right.circle.fill" : "chevron.right.circle")
                    .font(.system(size: 22))
                    .foregroundColor(canGoNext ? Theme.primaryBlue : Theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
        }
    }

    @ViewBuilder
    private func slotTitleLabel(for slotIdx: Int, centered: Bool) -> some View {
        let name = slotIdx < slotLabels.count ? slotLabels[slotIdx] : ""
        let hours = Self.slotHours[safe: slotIdx] ?? []
        let rangeText: String = {
            guard let first = hours.first, let last = hours.last else { return "" }
            return "\(formatHour(first)) – \(formatHour(last + 1))"
        }()
        VStack(alignment: centered ? .center : .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            if !rangeText.isEmpty {
                Text(rangeText)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: centered ? .infinity : nil, alignment: centered ? .center : .leading)
    }

    // MARK: - Hour bar

    private func hourBar(for slotIdx: Int) -> some View {
        let hours = Self.slotHours[safe: slotIdx] ?? []
        return VStack(alignment: .leading, spacing: 6) {
            tickLabelsRow(hours: hours)
            segmentBar(hours: hours, slotIdx: slotIdx)
        }
    }

    private func tickLabelsRow(hours: [Int]) -> some View {
        GeometryReader { geo in
            let count = hours.count
            guard count > 0 else { return AnyView(EmptyView()) }
            let segW = geo.size.width / CGFloat(count)
            return AnyView(
                ZStack(alignment: .topLeading) {
                    ForEach(hours.indices, id: \.self) { i in
                        let h = hours[i]
                        Text(formatHour(h))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize()
                            .position(x: (CGFloat(i) + 0.5) * segW, y: 7)
                    }
                }
            )
        }
        .frame(height: 14)
    }

    private func segmentBar(hours: [Int], slotIdx: Int) -> some View {
        GeometryReader { geo in
            let count = hours.count
            let spacing: CGFloat = 2
            let totalSpacing = count > 1 ? spacing * CGFloat(count - 1) : 0
            let segW = count > 0 ? (geo.size.width - totalSpacing) / CGFloat(count) : 0

            ZStack {
                // Visual segments
                HStack(spacing: spacing) {
                    ForEach(hours, id: \.self) { h in
                        let key = makeHourKey(date: focusedDayIso, slotIndex: slotIdx, hour: h)
                        let committed = selectedHourKeys.contains(key)
                        let inDrag = isInDragPreview(hour: h)
                        let otherColors = otherVoterHoursByKey[key] ?? []
                        RoundedRectangle(cornerRadius: 6)
                            .fill(segmentFill(committed: committed, inDrag: inDrag))
                            .overlay {
                                ZStack(alignment: .bottom) {
                                    if committed || (inDrag && !dragInitiallySelected) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .inset(by: 1)
                                            .stroke(Theme.primaryBlue, lineWidth: committed ? 4 : 1.5)
                                    }
                                    if !otherColors.isEmpty {
                                        VoterDots(colors: otherColors, maxVisible: 3)
                                            .frame(height: 12)
                                            .padding(.bottom, 2)
                                    }
                                }
                            }
                    }
                }
                .frame(height: 40)

                // Transparent drag-capture overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                let x = max(0, min(value.location.x, geo.size.width - 1))
                                let idx = Int(x / (segW + spacing))
                                let clamped = max(0, min(idx, count - 1))
                                let hour = hours[clamped]

                                if dragStartHour == nil {
                                    dragStartHour = hour
                                    let startKey = makeHourKey(date: focusedDayIso, slotIndex: slotIdx, hour: hour)
                                    dragInitiallySelected = selectedHourKeys.contains(startKey)
                                }
                                dragCurrentHour = hour
                            }
                            .onEnded { _ in
                                if let start = dragStartHour, let current = dragCurrentHour {
                                    onToggleRange(slotIdx, start, current, dragInitiallySelected)
                                }
                                resetDrag()
                            }
                    )
            }
        }
        .frame(height: 40)
    }

    // MARK: - Pure helpers

    private var currentSlotIndex: Int {
        guard focusedSlotPosition >= 0, focusedSlotPosition < slotWindows.count else { return 0 }
        return slotWindows[focusedSlotPosition]
    }

    private var canGoPrevious: Bool { focusedSlotPosition > 0 }
    private var canGoNext: Bool { focusedSlotPosition < slotWindows.count - 1 }

    private var slotWindows: [Int] {
        Array(0..<slotLabels.count)
    }

    private func resetDrag() {
        dragStartHour = nil
        dragCurrentHour = nil
        dragInitiallySelected = false
    }

    private func isInDragPreview(hour: Int) -> Bool {
        guard let start = dragStartHour, let current = dragCurrentHour else { return false }
        let lo = min(start, current)
        let hi = max(start, current)
        return hour >= lo && hour <= hi
    }

    private func segmentFill(committed: Bool, inDrag: Bool) -> Color {
        if inDrag {
            return dragInitiallySelected
                ? Theme.cellDefault.opacity(0.4)   // deselecting: fade out
                : Theme.primaryBlue.opacity(0.65)  // selecting: preview blue
        }
        return committed ? Theme.voteGreenHigh : Theme.cellDefault
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 24
        if h == 0 { return "12am" }
        if h == 12 { return "12pm" }
        return h < 12 ? "\(h)am" : "\(h - 12)pm"
    }

    private func dayLabel(_ iso: String) -> String {
        guard let (_, _, day) = parseISODate(iso) else { return iso }
        return "\(fullWeekdayNameFromIso(iso)) \(day) · \(monthNameFromIso(iso))"
    }

    private func monthNameFromIso(_ iso: String) -> String {
        guard let (_, m, _) = parseISODate(iso) else { return "" }
        return monthName(m)
    }

    private func fullWeekdayNameFromIso(_ iso: String) -> String {
        guard let (y, m, d) = parseISODate(iso) else { return "" }
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: y, month: m + 1, day: d)) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func clampFocusedDayToOptions() {
        guard !dayOptions.isEmpty else { return }
        if !dayOptions.contains(focusedDayIso) {
            focusedDayIso = dayOptions[0]
        }
    }

    private func syncFocusedSlotWithSelection() {
        guard !slotWindows.isEmpty else {
            focusedSlotPosition = 0
            return
        }

        // Use .min() to get the lowest slot index deterministically,
        // avoiding non-deterministic Set iteration order.
        let selectedSlotForDay: Int? = selectedHourKeys
            .compactMap(parseHourKey)
            .filter { $0.date == focusedDayIso }
            .map(\.slotIndex)
            .min()
            ?? selectedSlotKeys
                .compactMap(parseSlotKey)
                .filter { $0.date == focusedDayIso }
                .map(\.slotIndex)
                .min()

        if let selectedSlotForDay,
           let selectedPosition = slotWindows.firstIndex(of: selectedSlotForDay) {
            focusedSlotPosition = selectedPosition
        } else {
            focusedSlotPosition = min(focusedSlotPosition, slotWindows.count - 1)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
