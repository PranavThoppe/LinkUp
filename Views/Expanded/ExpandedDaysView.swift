import SwiftUI

struct ExpandedDaysView: View {
    let payload: MessagePayload
    let selfSenderId: String
    @ObservedObject var voteDraft: DaysVoteDraft
    let onDone: (MessagePayload) -> Void

    @State private var focusedWindowIndex: Int = 0

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]
    private let maxDaysPerRow = 5
    private let fixedColWidth: CGFloat = 44

    init(
        payload: MessagePayload,
        selfSenderId: String,
        voteDraft: DaysVoteDraft,
        onDone: @escaping (MessagePayload) -> Void
    ) {
        self.payload = payload
        self.selfSenderId = selfSenderId
        self.voteDraft = voteDraft
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)
            ScrollView {
                VStack(spacing: 20) {
                    if dayColumns.isEmpty {
                        Text("No days selected.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(24)
                    } else {
                        gridCard
                        SlotHourPickerCard(
                            dayOptions: hourPickerDayOptions,
                            focusedDayIso: $voteDraft.focusedDayIso,
                            selectedHourKeys: $voteDraft.selectedHourKeys,
                            otherVoterHoursByKey: otherVoterHoursByKey,
                            slotLabels: slotLabels,
                            onToggleRange: { slotIdx, start, end, initiallySelected in
                                voteDraft.toggleHoursInRange(
                                    date: voteDraft.focusedDayIso,
                                    slotIndex: slotIdx,
                                    startHour: start,
                                    endHour: end,
                                    initiallySelected: initiallySelected
                                )
                            }
                        )
                    }

                    VoterLegendCard(
                        participants: allVoters,
                        subtitleForParticipant: legendSubtitle
                    )
                }
                .padding(16)
            }
        }
        .background(Theme.background)
        .onAppear {
            syncWindowAndFocusedDay()
        }
        .onChange(of: pollDaysSignature) { _, _ in
            syncWindowAndFocusedDay()
        }
        .onChange(of: hourPickerDayOptionsSignature) { _, _ in
            syncFocusedDayToHourPickerOptions()
        }
        .onChange(of: voteDraft.focusedDayIso) { _, newIso in
            guard !newIso.isEmpty,
                  let idx = dayWindows.firstIndex(where: { $0.contains(newIso) }) else { return }
            focusedWindowIndex = idx
        }
    }

    // MARK: - Grid card

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dayWindows.count > 1 {
                windowNavigationRow
            }
            SlotDayGrid(
                days: currentWindowDays,
                slotLabels: slotLabels,
                selfWholeDays: voteDraft.selectedDates,
                selfSlotKeys: voteDraft.selectedSlotKeys,
                otherVoterSlotsByKey: otherVoterSlotsByKey,
                totalVoteCountsBySlotKey: totalVoteCountsBySlotKey,
                otherVoterDaysByIso: otherVoterDaysByIso,
                showVoterDots: true,
                colWidth: fixedColWidth,
                isInteractive: true,
                onToggleWholeDay: { voteDraft.toggleWholeDay($0) },
                onToggleSlot: { voteDraft.toggleSlot(date: $0, slotIndex: $1) }
            )
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    private var windowNavigationRow: some View {
        HStack(spacing: 12) {
            Button {
                goToPreviousWindow()
            } label: {
                Image(systemName: canGoToPreviousWindow ? "chevron.left.circle.fill" : "chevron.left.circle")
                    .font(.system(size: 22))
                    .foregroundColor(canGoToPreviousWindow ? Theme.primaryBlue : Theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPreviousWindow)

            Text(currentWindowRangeTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)

            Button {
                goToNextWindow()
            } label: {
                Image(systemName: canGoToNextWindow ? "chevron.right.circle.fill" : "chevron.right.circle")
                    .font(.system(size: 22))
                    .foregroundColor(canGoToNextWindow ? Theme.primaryBlue : Theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextWindow)
        }
    }

    private var canGoToPreviousWindow: Bool {
        !dayWindows.isEmpty && focusedWindowIndex > 0
    }

    private var canGoToNextWindow: Bool {
        !dayWindows.isEmpty && focusedWindowIndex < dayWindows.count - 1
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        let isSaveEnabled = hasSlotVoteChanges(
            payload: payload,
            selfSenderId: selfSenderId,
            wholeDayDates: voteDraft.selectedDates,
            selectedSlotKeys: voteDraft.selectedSlotKeys,
            selectedHourKeys: voteDraft.selectedHourKeys
        )
        return HStack(alignment: .center) {
            toolbarLeading
            Spacer()
            Button("Save") {
                onDone(buildUpdatedSlotPayload(
                    payload: payload,
                    selfSenderId: selfSenderId,
                    wholeDayDates: voteDraft.selectedDates,
                    selectedSlotKeys: voteDraft.selectedSlotKeys,
                    selectedHourKeys: voteDraft.selectedHourKeys
                ))
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isSaveEnabled ? Theme.primaryBlue : Theme.textSecondary.opacity(0.55))
            .disabled(!isSaveEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    @ViewBuilder
    private var toolbarLeading: some View {
        let count = dayColumns.count
        if hasCustomTitle {
            VStack(alignment: .leading, spacing: 4) {
                Text(trimmedTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(count) specific day\(count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .bold))
                    Text("DAYS")
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.6)
                }
                .foregroundColor(Theme.primaryBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.primaryBlue.opacity(0.14))
                .clipShape(Capsule())

                Text(untitledDaysHeadline)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    // MARK: - Computed

    private var trimmedTitle: String {
        (payload.schedule.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasCustomTitle: Bool {
        !trimmedTitle.isEmpty
    }

    private var untitledDaysHeadline: String {
        let count = dayColumns.count
        guard count > 0 else { return "Specific Day Availability" }
        let countText = "\(count) specific day\(count == 1 ? "" : "s")"
        let monthText = selectedMonthsSummary
        guard !monthText.isEmpty else { return countText }
        return "\(countText) · \(monthText)"
    }

    private var selectedMonthsSummary: String {
        let uniqueMonths = Array(Set(dayColumns.compactMap { iso -> Int? in
            guard let (_, month, _) = parseISODate(iso) else { return nil }
            return month
        })).sorted()
        let names = uniqueMonths.map { monthName($0) }

        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return "\(names[0])–\(names[1])"
        default:
            return "\(names[0]), \(names[1]), \(names[2])"
        }
    }

    private var dayColumns: [String] {
        (payload.schedule.specificDates ?? []).sorted()
    }

    private var pollDaysSignature: String {
        dayColumns.joined(separator: "|")
    }

    private var hourPickerDayOptions: [String] {
        let linked = Set(DaysVoteDraft.linkedDayOptions(pollDays: dayColumns, votes: payload.votes))
        return dayColumns.filter { linked.contains($0) || selfVotedDays.contains($0) }
    }

    private var hourPickerDayOptionsSignature: String {
        hourPickerDayOptions.joined(separator: "|")
    }

    private var selfVotedDays: Set<String> {
        var days = Set(voteDraft.selectedDates)
        for key in voteDraft.selectedSlotKeys {
            if let slot = parseSlotKey(key) {
                days.insert(slot.date)
            }
        }
        for key in voteDraft.selectedHourKeys {
            if let hour = parseHourKey(key) {
                days.insert(hour.date)
            }
        }
        return days
    }

    private var dayWindows: [[String]] {
        stride(from: 0, to: dayColumns.count, by: maxDaysPerRow).map { start in
            let end = min(start + maxDaysPerRow, dayColumns.count)
            return Array(dayColumns[start..<end])
        }
    }

    private var currentWindowDays: [String] {
        guard focusedWindowIndex >= 0, focusedWindowIndex < dayWindows.count else { return [] }
        return dayWindows[focusedWindowIndex]
    }

    private var currentWindowRangeTitle: String {
        let days = currentWindowDays
        guard let first = days.first, let last = days.last else { return "" }
        return monthDayRangeLabel(startIso: first, endIso: last)
    }

    private func syncWindowAndFocusedDay() {
        voteDraft.syncFocusedDayWithPollDays(dayColumns)
        syncFocusedDayToHourPickerOptions()
        if let idx = dayWindows.firstIndex(where: { $0.contains(voteDraft.focusedDayIso) }) {
            focusedWindowIndex = idx
        } else {
            focusedWindowIndex = 0
            voteDraft.focusedDayIso = dayWindows.first?.first ?? ""
        }
    }

    private func syncFocusedDayToHourPickerOptions() {
        let options = hourPickerDayOptions
        guard !options.isEmpty else { return }
        if !options.contains(voteDraft.focusedDayIso) {
            voteDraft.focusedDayIso = options[0]
        }
    }

    private func goToPreviousWindow() {
        let windows = dayWindows
        guard canGoToPreviousWindow else { return }
        focusedWindowIndex -= 1
        voteDraft.focusedDayIso = windows[focusedWindowIndex][0]
        syncFocusedDayToHourPickerOptions()
    }

    private func goToNextWindow() {
        let windows = dayWindows
        guard canGoToNextWindow else { return }
        focusedWindowIndex += 1
        voteDraft.focusedDayIso = windows[focusedWindowIndex][0]
        syncFocusedDayToHourPickerOptions()
    }

    private var otherVoterSlotsByKey: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            for slot in vote.slots ?? [] {
                let key = makeSlotKey(date: slot.date, slotIndex: slot.slotIndex)
                map[key, default: []].append(vote.senderColor)
            }
            for iso in vote.dates {
                for slotIdx in 0..<slotLabels.count {
                    let key = makeSlotKey(date: iso, slotIndex: slotIdx)
                    if !map[key, default: []].contains(vote.senderColor) {
                        map[key, default: []].append(vote.senderColor)
                    }
                }
            }
        }
        return map
    }

    private var totalVoteCountsBySlotKey: [String: Int] {
        let pollDays = Set(dayColumns)
        var votersBySlot: [String: Set<String>] = [:]

        for vote in payload.votes where vote.senderId != selfSenderId {
            for slot in vote.slots ?? [] where pollDays.contains(slot.date) {
                let key = makeSlotKey(date: slot.date, slotIndex: slot.slotIndex)
                votersBySlot[key, default: []].insert(vote.senderId)
            }
            for iso in vote.dates where pollDays.contains(iso) {
                for slotIdx in 0..<slotLabels.count {
                    let key = makeSlotKey(date: iso, slotIndex: slotIdx)
                    votersBySlot[key, default: []].insert(vote.senderId)
                }
            }
        }

        for iso in voteDraft.selectedDates where pollDays.contains(iso) {
            for slotIdx in 0..<slotLabels.count {
                let key = makeSlotKey(date: iso, slotIndex: slotIdx)
                votersBySlot[key, default: []].insert(selfSenderId)
            }
        }
        for key in voteDraft.selectedSlotKeys {
            if let slot = parseSlotKey(key), pollDays.contains(slot.date) {
                let normalizedKey = makeSlotKey(date: slot.date, slotIndex: slot.slotIndex)
                votersBySlot[normalizedKey, default: []].insert(selfSenderId)
            }
        }

        return votersBySlot.mapValues(\.count)
    }

    private var otherVoterDaysByIso: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            let activeDays: Set<String> = Set(vote.dates)
                .union(Set((vote.slots ?? []).map(\.date)))
            for iso in activeDays {
                if !map[iso, default: []].contains(vote.senderColor) {
                    map[iso, default: []].append(vote.senderColor)
                }
            }
        }
        return map
    }

    private var otherVoterHoursByKey: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            for hour in vote.hours ?? [] {
                let key = makeHourKey(date: hour.date, slotIndex: hour.slotIndex, hour: hour.hour)
                if !map[key, default: []].contains(vote.senderColor) {
                    map[key, default: []].append(vote.senderColor)
                }
            }
        }
        return map
    }

    private var allVoters: [Participant] {
        let ids = Set(payload.votes.map { $0.senderId })
        return payload.participants.filter { ids.contains($0.id) }
    }

    // TODO: Revisit how we summarize votes in the legend — slot counts ignore optional hour picks
    // and may not reflect nuanced availability; consider hours or a clearer breakdown later.
    private func legendSubtitle(for participant: Participant) -> String {
        let isMe = participant.id == selfSenderId
        let count: Int
        if isMe {
            let slotCount = voteDraft.selectedSlotKeys.count
            let wholeDaySlots = voteDraft.selectedDates.count * slotLabels.count
            count = slotCount + wholeDaySlots
        } else {
            let vote = payload.votes.first { $0.senderId == participant.id }
            let slots = (vote?.slots ?? []).count
            let wholeDaySlots = (vote?.dates ?? []).count * slotLabels.count
            count = slots + wholeDaySlots
        }
        let label = isMe ? "You" : participant.initial
        return "\(label) · \(count) slot\(count == 1 ? "" : "s")"
    }
}
