import SwiftUI

struct ExpandedCalendarView: View {
    let payload: MessagePayload
    let selfSenderId: String
    let onDone: (MessagePayload) -> Void

    @State private var selectedDates: Set<String>

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    init(payload: MessagePayload, selfSenderId: String, onDone: @escaping (MessagePayload) -> Void) {
        self.payload = payload
        self.selfSenderId = selfSenderId
        self.onDone = onDone
        let existing = payload.votes.first { $0.senderId == selfSenderId }
        _selectedDates = State(initialValue: Set(existing?.dates ?? []))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(payload.schedule.months ?? [], id: \.self) { month in
                        monthCard(month)
                    }
                    voterLegend
                }
                .padding(16)
            }
        }
        .background(Theme.background)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let title = payload.schedule.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                let monthsText = payload.schedule.months?
                    .map { monthName($0.month) }
                    .joined(separator: ", ") ?? ""
                if !monthsText.isEmpty {
                    Text(monthsText)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            Button("Done") {
                onDone(buildUpdatedPayload())
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Theme.primaryBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - Month card

    private func monthCard(_ month: MonthYear) -> some View {
        let grid = buildMonthGridSunFirst(month: month.month, year: month.year)
        let rows = stride(from: 0, to: grid.count, by: 7)
            .map { Array(grid[$0..<min($0 + 7, grid.count)]) }

        return VStack(spacing: 12) {
            Text(monthHeaderTitle(for: month))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

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
            let isSelf = selectedDates.contains(iso)
            let otherColors = otherVoterColorsByDate[iso] ?? []
            let bgColor: Color = isSelf
                ? Theme.primaryBlue
                : (otherColors.isEmpty
                    ? Theme.cellDefault
                    : VoteHeatmap.color(for: otherColors.count, maxCount: maxOtherVotes))

            Button {
                var next = selectedDates
                if next.contains(iso) {
                    next.remove(iso)
                } else {
                    next.insert(iso)
                }
                selectedDates = next
            } label: {
                VStack(spacing: 2) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bgColor)
                            .frame(width: 36, height: 36)
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
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
    }

    // MARK: - Voter legend

    private var voterLegend: some View {
        Group {
            if !allVoters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(allVoters.count) response\(allVoters.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    ForEach(allVoters, id: \.id) { participant in
                        let count = dateVoteCount(for: participant.id)
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: participant.color))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(participant.initial)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            Text(participant.id == selfSenderId
                                 ? "You · \(count) day\(count == 1 ? "" : "s")"
                                 : "\(participant.initial) · \(count) day\(count == 1 ? "" : "s")")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.cardBackground)
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Computed

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

    private var allVoters: [Participant] {
        let voterIds = Set(payload.votes.map { $0.senderId })
        return payload.participants.filter { voterIds.contains($0.id) }
    }

    private func dateVoteCount(for participantId: String) -> Int {
        if participantId == selfSenderId { return selectedDates.count }
        return payload.votes.first { $0.senderId == participantId }?.dates.count ?? 0
    }

    private func monthHeaderTitle(for month: MonthYear) -> String {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        return month.year == currentYear
            ? monthName(month.month)
            : "\(monthName(month.month)) \(month.year)"
    }

    // MARK: - Build updated payload

    private func buildUpdatedPayload() -> MessagePayload {
        let (selfColor, selfInitial, updatedParticipants) = resolvedSelfIdentity()
        let existingId = payload.votes.first { $0.senderId == selfSenderId }?.id ?? UUID()

        var updatedVotes = payload.votes.filter { $0.senderId != selfSenderId }
        if !selectedDates.isEmpty {
            let newVote = Vote(
                id: existingId,
                senderId: selfSenderId,
                senderInitial: selfInitial,
                senderColor: selfColor,
                dates: Array(selectedDates).sorted(),
                slots: nil,
                updatedAt: Date()
            )
            updatedVotes.append(newVote)
        }

        return MessagePayload(
            version: payload.version,
            schedule: payload.schedule.stampedNow(),
            votes: updatedVotes,
            participants: updatedParticipants,
            revision: payload.revision + 1,
            lastWriterId: selfSenderId
        )
    }

    private func resolvedSelfIdentity() -> (color: String, initial: String, participants: [Participant]) {
        if let existing = payload.participants.first(where: { $0.id == selfSenderId }) {
            return (existing.color, existing.initial, payload.participants)
        }
        let color = Participant.color(for: payload.participants.count)
        let initial = String(selfSenderId.prefix(1)).uppercased()
        let newParticipant = Participant(id: selfSenderId, initial: initial, color: color)
        return (color, initial, payload.participants + [newParticipant])
    }
}
