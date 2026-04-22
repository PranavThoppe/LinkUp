import SwiftUI

struct ExpandedDaysView: View {
    let payload: MessagePayload
    let selfSenderId: String
    @ObservedObject var voteDraft: DaysVoteDraft
    let onDone: (MessagePayload) -> Void

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
    }

    // MARK: - Grid card

    private var gridCard: some View {
        VStack(spacing: 12) {
            ForEach(dayChunks.indices, id: \.self) { idx in
                SlotDayGrid(
                    days: dayChunks[idx],
                    slotLabels: slotLabels,
                    selfWholeDays: voteDraft.selectedDates,
                    selfSlotKeys: voteDraft.selectedSlotKeys,
                    otherVoterSlotsByKey: otherVoterSlotsByKey,
                    otherVoterDaysByIso: otherVoterDaysByIso,
                    showVoterDots: true,
                    colWidth: fixedColWidth,
                    isInteractive: true,
                    onToggleWholeDay: { voteDraft.toggleWholeDay($0) },
                    onToggleSlot: { voteDraft.toggleSlot(date: $0, slotIndex: $1) }
                )
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(alignment: .center) {
            toolbarLeading
            Spacer()
            Button("Save") {
                onDone(buildUpdatedSlotPayload(
                    payload: payload,
                    selfSenderId: selfSenderId,
                    wholeDayDates: voteDraft.selectedDates,
                    selectedSlotKeys: voteDraft.selectedSlotKeys
                ))
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Theme.primaryBlue)
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

    private var dayChunks: [[String]] {
        stride(from: 0, to: dayColumns.count, by: maxDaysPerRow).map { start in
            let end = min(start + maxDaysPerRow, dayColumns.count)
            return Array(dayColumns[start..<end])
        }
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

    private var allVoters: [Participant] {
        let ids = Set(payload.votes.map { $0.senderId })
        return payload.participants.filter { ids.contains($0.id) }
    }

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
