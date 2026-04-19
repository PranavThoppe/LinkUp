import SwiftUI

struct ExpandedWeekView: View {
    let payload: MessagePayload
    let selfSenderId: String
    let onDone: (MessagePayload) -> Void

    @State private var selectedSlots: Set<String>

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    init(payload: MessagePayload, selfSenderId: String, onDone: @escaping (MessagePayload) -> Void) {
        self.payload = payload
        self.selfSenderId = selfSenderId
        self.onDone = onDone
        let existing = payload.votes.first { $0.senderId == selfSenderId }
        let keys = (existing?.slots ?? []).map { "\($0.date)#\($0.slotIndex)" }
        _selectedSlots = State(initialValue: Set(keys))
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
                        Text("No week range configured.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .padding(24)
                    } else {
                        VoteToggleGrid(
                            dayColumns: dayColumns,
                            slotLabels: slotLabels,
                            selectedSlots: $selectedSlots,
                            otherVoterSlots: otherVoterSlotsByKey
                        )
                        .padding(16)
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
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
                if let range = payload.schedule.weekRange {
                    let parts = [range.startIso, range.endIso]
                        .compactMap { transcriptDayColumnParts(iso: $0) }
                    if parts.count == 2 {
                        Text("\(monthNameFromIso(range.startIso)) \(parts[0].day) – \(parts[1].day)")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
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

    // MARK: - Voter legend

    private var voterLegend: some View {
        Group {
            if !allVoters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(allVoters.count) response\(allVoters.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    ForEach(allVoters, id: \.id) { participant in
                        let count = slotVoteCount(for: participant.id)
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
                                 ? "You · \(count) slot\(count == 1 ? "" : "s")"
                                 : "\(participant.initial) · \(count) slot\(count == 1 ? "" : "s")")
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

    private var dayColumns: [String] {
        guard let range = payload.schedule.weekRange else { return [] }
        return dateRangeInclusive(startIso: range.startIso, endIso: range.endIso)
    }

    private var otherVoterSlotsByKey: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes where vote.senderId != selfSenderId {
            for slot in vote.slots ?? [] {
                let key = "\(slot.date)#\(slot.slotIndex)"
                map[key, default: []].append(vote.senderColor)
            }
        }
        return map
    }

    private var allVoters: [Participant] {
        let ids = Set(payload.votes.map { $0.senderId })
        return payload.participants.filter { ids.contains($0.id) }
    }

    private func slotVoteCount(for participantId: String) -> Int {
        if participantId == selfSenderId { return selectedSlots.count }
        return payload.votes.first { $0.senderId == participantId }?.slots?.count ?? 0
    }

    private func monthNameFromIso(_ iso: String) -> String {
        guard let (_, m, _) = parseISODate(iso) else { return "" }
        return monthName(m)
    }

    // MARK: - Build updated payload

    private func buildUpdatedPayload() -> MessagePayload {
        let (selfColor, selfInitial, updatedParticipants) = resolvedSelfIdentity()
        let slots = selectedSlots.sorted().compactMap { key -> SlotSelection? in
            let parts = key.split(separator: "#")
            guard parts.count == 2, let idx = Int(parts[1]) else { return nil }
            return SlotSelection(date: String(parts[0]), slotIndex: idx)
        }
        let existingId = payload.votes.first { $0.senderId == selfSenderId }?.id ?? UUID()

        var updatedVotes = payload.votes.filter { $0.senderId != selfSenderId }
        if !slots.isEmpty {
            let newVote = Vote(
                id: existingId,
                senderId: selfSenderId,
                senderInitial: selfInitial,
                senderColor: selfColor,
                dates: [],
                slots: slots,
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
