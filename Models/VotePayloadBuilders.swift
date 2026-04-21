import Foundation

// MARK: - Shared identity resolution

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
