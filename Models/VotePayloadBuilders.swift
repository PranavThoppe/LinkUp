import Foundation

// MARK: - Shared identity resolution

private func existingVoteState(
    payload: MessagePayload,
    selfSenderId: String
) -> (dates: Set<String>, slotKeys: Set<String>) {
    guard let existing = payload.votes.first(where: { $0.senderId == selfSenderId }) else {
        return ([], [])
    }

    let existingDates = Set(existing.dates)
    let existingSlotKeys = Set((existing.slots ?? []).map { makeSlotKey(date: $0.date, slotIndex: $0.slotIndex) })
    return (existingDates, existingSlotKeys)
}

func hasMonthVoteChanges(
    payload: MessagePayload,
    selfSenderId: String,
    selectedDates: Set<String>,
    selectedSlotKeys: Set<String>
) -> Bool {
    let existing = existingVoteState(payload: payload, selfSenderId: selfSenderId)

    let normalizedDates: Set<String>
    let normalizedSlotKeys: Set<String>
    if let pollDates = payload.schedule.eligiblePollDates {
        normalizedDates = selectedDates.intersection(pollDates)
        normalizedSlotKeys = Set(selectedSlotKeys.filter { key in
            parseSlotKey(key).map { pollDates.contains($0.date) } ?? false
        })
    } else {
        normalizedDates = selectedDates
        normalizedSlotKeys = selectedSlotKeys
    }

    return normalizedDates != existing.dates || normalizedSlotKeys != existing.slotKeys
}

func hasSlotVoteChanges(
    payload: MessagePayload,
    selfSenderId: String,
    wholeDayDates: Set<String>,
    selectedSlotKeys: Set<String>
) -> Bool {
    let existing = existingVoteState(payload: payload, selfSenderId: selfSenderId)
    return wholeDayDates != existing.dates || selectedSlotKeys != existing.slotKeys
}

/// Resolves the current user's color, initial, and the updated participants list.
/// If the user is not yet in `payload.participants`, they are appended.
func resolvedSelfIdentity(
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

// MARK: - Slot payload builder (week + days modes)

/// Builds an updated `MessagePayload` for week or days modes, merging the current user's
/// whole-day availability and per-slot picks into the votes array.
///
/// - Parameters:
///   - wholeDayDates: ISO date strings where the user is available all day.
///   - selectedSlotKeys: `"YYYY-MM-DD#slotIndex"` keys for per-slot picks
///     (should only include days NOT in `wholeDayDates`; `SlotVoteDraft` enforces this).
func buildUpdatedSlotPayload(
    payload: MessagePayload,
    selfSenderId: String,
    wholeDayDates: Set<String>,
    selectedSlotKeys: Set<String>
) -> MessagePayload {
    let (selfColor, selfInitial, updatedParticipants) = resolvedSelfIdentity(
        payload: payload,
        selfSenderId: selfSenderId
    )

    let slots: [SlotSelection] = selectedSlotKeys.sorted().compactMap { key in
        let parts = key.split(separator: "#")
        guard parts.count == 2, let idx = Int(parts[1]) else { return nil }
        return SlotSelection(date: String(parts[0]), slotIndex: idx)
    }

    let sortedWholeDays = wholeDayDates.sorted()

    let existingId = payload.votes.first { $0.senderId == selfSenderId }?.id ?? UUID()

    var updatedVotes = payload.votes.filter { $0.senderId != selfSenderId }
    if !sortedWholeDays.isEmpty || !slots.isEmpty {
        let newVote = Vote(
            id: existingId,
            senderId: selfSenderId,
            senderInitial: selfInitial,
            senderColor: selfColor,
            dates: sortedWholeDays,
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
