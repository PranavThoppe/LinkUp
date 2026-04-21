import Foundation
import Combine

/// Shared ObservableObject for week and days voting state.
/// Tracks both whole-day availability (`selectedDates`) and per-slot picks (`selectedSlotKeys`).
/// Toggle rules mirror the MVP's `toggleWholeDayWeekVote` / `toggleSlotWeekVote` in WeekCard.tsx.
final class SlotVoteDraft: ObservableObject {
    /// Whole-day ISO date strings (YYYY-MM-DD). A date here means ALL slots are available.
    @Published var selectedDates: Set<String>
    /// Per-slot keys in `"YYYY-MM-DD#slotIndex"` format, only for days NOT in `selectedDates`.
    @Published var selectedSlotKeys: Set<String>

    private static let slotCount = 4

    init(selectedDates: Set<String>, selectedSlotKeys: Set<String>) {
        self.selectedDates = selectedDates
        self.selectedSlotKeys = selectedSlotKeys
    }

    convenience init(payload: MessagePayload, selfSenderId: String) {
        let existing = payload.votes.first { $0.senderId == selfSenderId }
        let wholeDays = Set(existing?.dates ?? [])
        let slotKeys = Set((existing?.slots ?? []).map { makeSlotKey(date: $0.date, slotIndex: $0.slotIndex) })
        self.init(selectedDates: wholeDays, selectedSlotKeys: slotKeys)
    }

    // MARK: - Toggle rules

    /// Tapping the DOW label or date badge for an ISO date.
    /// - If already whole-day: remove it (partial slot picks for that day remain).
    /// - If not: add as whole-day and clear any per-slot picks for that date.
    func toggleWholeDay(_ iso: String) {
        if selectedDates.contains(iso) {
            selectedDates.remove(iso)
        } else {
            selectedDates.insert(iso)
            selectedSlotKeys = selectedSlotKeys.filter { !$0.hasPrefix("\(iso)#") }
        }
    }

    /// Tapping a slot cell.
    /// - If the date is currently whole-day: remove whole-day, then fill in all OTHER slots
    ///   for that day (the tapped slot is excluded), leaving specific per-slot picks.
    /// - If not whole-day: toggle the specific slot key.
    func toggleSlot(date iso: String, slotIndex: Int) {
        if selectedDates.contains(iso) {
            selectedDates.remove(iso)
            let otherSlots = (0..<Self.slotCount)
                .filter { $0 != slotIndex }
                .map { makeSlotKey(date: iso, slotIndex: $0) }
            let kept = selectedSlotKeys.filter { !$0.hasPrefix("\(iso)#") }
            selectedSlotKeys = kept.union(otherSlots)
        } else {
            let key = makeSlotKey(date: iso, slotIndex: slotIndex)
            if selectedSlotKeys.contains(key) {
                selectedSlotKeys.remove(key)
            } else {
                selectedSlotKeys.insert(key)
            }
        }
    }

    // MARK: - Query helpers

    /// True when the user has any availability (whole-day or any slot) on `iso`.
    func hasAnyPick(on iso: String) -> Bool {
        if selectedDates.contains(iso) { return true }
        return selectedSlotKeys.contains { $0.hasPrefix("\(iso)#") }
    }

    /// True when the user's availability covers the given slot
    /// (either via whole-day or an explicit per-slot key).
    func coversSlot(date iso: String, slotIndex: Int) -> Bool {
        if selectedDates.contains(iso) { return true }
        return selectedSlotKeys.contains(makeSlotKey(date: iso, slotIndex: slotIndex))
    }

    var hasAnyVote: Bool {
        !selectedDates.isEmpty || !selectedSlotKeys.isEmpty
    }
}

/// Concrete type used by ExpandedWeekView.
typealias WeekVoteDraft = SlotVoteDraft
/// Concrete type used by ExpandedDaysView.
typealias DaysVoteDraft = SlotVoteDraft
