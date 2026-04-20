import Foundation
import Combine


final class MonthVoteDraft: ObservableObject {
    @Published var selectedDates: Set<String>
    @Published var selectedSlotKeys: Set<String>
    /// ISO day key for slot editing (expanded legend picker + compact day picker).
    @Published var focusedDayIso: String = ""

    init(selectedDates: Set<String>, selectedSlotKeys: Set<String>) {
        self.selectedDates = selectedDates
        self.selectedSlotKeys = selectedSlotKeys
    }

    convenience init(payload: MessagePayload, selfSenderId: String) {
        let existing = payload.votes.first { $0.senderId == selfSenderId }
        let slots = existing?.slots ?? []
        let slotDates = Set(slots.map(\.date))
        let selectedDates = Set(existing?.dates ?? []).union(slotDates)
        let slotKeys = Set(slots.map { makeSlotKey(date: $0.date, slotIndex: $0.slotIndex) })
        self.init(selectedDates: selectedDates, selectedSlotKeys: slotKeys)
    }

    var sortedDates: [String] {
        selectedDates.sorted()
    }

    func syncFocusedDayWithSelection() {
        let dates = sortedDates
        guard !dates.isEmpty else {
            focusedDayIso = ""
            return
        }
        if !dates.contains(focusedDayIso) {
            focusedDayIso = dates[0]
        }
    }

    func toggleDate(_ isoDate: String) {
        if selectedDates.contains(isoDate) {
            selectedDates.remove(isoDate)
            selectedSlotKeys = selectedSlotKeys.filter { !($0.hasPrefix("\(isoDate)#")) }
        } else {
            selectedDates.insert(isoDate)
        }
        syncFocusedDayWithSelection()
    }

    var filteredSortedSlots: [SlotSelection] {
        monthSlotSelections(from: selectedSlotKeys, allowedDates: selectedDates)
    }
}

func makeSlotKey(date: String, slotIndex: Int) -> String {
    "\(date)#\(slotIndex)"
}

func parseSlotKey(_ key: String) -> SlotSelection? {
    let parts = key.split(separator: "#")
    guard parts.count == 2, let slotIndex = Int(parts[1]) else { return nil }
    return SlotSelection(date: String(parts[0]), slotIndex: slotIndex)
}

func monthSlotSelections(from selectedSlotKeys: Set<String>, allowedDates: Set<String>) -> [SlotSelection] {
    selectedSlotKeys
        .compactMap(parseSlotKey)
        .filter { allowedDates.contains($0.date) }
        .sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.slotIndex < $1.slotIndex
        }
}

func buildUpdatedMonthPayload(
    payload: MessagePayload,
    selfSenderId: String,
    selectedDates: Set<String>,
    selectedSlotKeys: Set<String>
) -> MessagePayload {
    let slots = monthSlotSelections(from: selectedSlotKeys, allowedDates: selectedDates)
    let sortedDates = selectedDates.sorted()

    let (selfColor, selfInitial, updatedParticipants) = resolvedMonthSelfIdentity(
        payload: payload,
        selfSenderId: selfSenderId
    )
    let existingId = payload.votes.first { $0.senderId == selfSenderId }?.id ?? UUID()

    var updatedVotes = payload.votes.filter { $0.senderId != selfSenderId }
    if !sortedDates.isEmpty {
        let newVote = Vote(
            id: existingId,
            senderId: selfSenderId,
            senderInitial: selfInitial,
            senderColor: selfColor,
            dates: sortedDates,
            slots: slots.isEmpty ? nil : slots,
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

private func resolvedMonthSelfIdentity(
    payload: MessagePayload,
    selfSenderId: String
) -> (color: String, initial: String, participants: [Participant]) {
    if let existing = payload.participants.first(where: { $0.id == selfSenderId }) {
        return (existing.color, existing.initial, payload.participants)
    }
    let color = Participant.color(for: payload.participants.count)
    let initial = String(selfSenderId.prefix(1)).uppercased()
    let newParticipant = Participant(id: selfSenderId, initial: initial, color: color)
    return (color, initial, payload.participants + [newParticipant])
}
