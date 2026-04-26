import Foundation
import Combine

/// Shared ObservableObject for week and days voting state.
/// Tracks whole-day availability (`selectedDates`), per-slot picks (`selectedSlotKeys`),
/// and optional hour-level picks within a slot (`selectedHourKeys`).
final class SlotVoteDraft: ObservableObject {
    /// Whole-day ISO date strings (YYYY-MM-DD). A date here means ALL slots are available.
    @Published var selectedDates: Set<String>
    /// Per-slot keys in `"YYYY-MM-DD#slotIndex"` format, only for days NOT in `selectedDates`.
    @Published var selectedSlotKeys: Set<String>
    /// Hour-level keys in `"YYYY-MM-DD#slotIndex#hour"` format.
    /// Independent of slot-level picks — a slot can be voted on without any hour picks.
    @Published var selectedHourKeys: Set<String>
    /// Poll day used for the hour picker card (week/days modes).
    @Published var focusedDayIso: String = ""

    private static let slotCount = 4

    init(selectedDates: Set<String>, selectedSlotKeys: Set<String>, selectedHourKeys: Set<String> = []) {
        self.selectedDates = selectedDates
        self.selectedSlotKeys = selectedSlotKeys
        self.selectedHourKeys = selectedHourKeys
    }

    convenience init(payload: MessagePayload, selfSenderId: String) {
        let existing = payload.votes.first { $0.senderId == selfSenderId }
        let wholeDays = Set(existing?.dates ?? [])
        let slotKeys = Set((existing?.slots ?? []).map { makeSlotKey(date: $0.date, slotIndex: $0.slotIndex) })
        let hourKeys = Set((existing?.hours ?? []).map { makeHourKey(date: $0.date, slotIndex: $0.slotIndex, hour: $0.hour) })
        self.init(selectedDates: wholeDays, selectedSlotKeys: slotKeys, selectedHourKeys: hourKeys)
    }

    // MARK: - Toggle rules

    /// Tapping the DOW label or date badge for an ISO date.
    /// - If already whole-day: remove it (partial slot picks for that day remain).
    /// - If not: add as whole-day and clear any per-slot picks for that date.
    func toggleWholeDay(_ iso: String) {
        removeHours(for: iso)
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
            removeHours(for: iso)
            let otherSlots = (0..<Self.slotCount)
                .filter { $0 != slotIndex }
                .map { makeSlotKey(date: iso, slotIndex: $0) }
            let kept = selectedSlotKeys.filter { !$0.hasPrefix("\(iso)#") }
            selectedSlotKeys = kept.union(otherSlots)
        } else {
            let key = makeSlotKey(date: iso, slotIndex: slotIndex)
            if selectedSlotKeys.contains(key) {
                selectedSlotKeys.remove(key)
                removeHours(for: iso, slotIndex: slotIndex)
            } else {
                selectedSlotKeys.insert(key)
            }
        }
    }

    // MARK: - Hour toggle rules

    /// Drag-to-select/deselect a range of hours within a slot.
    /// - If `startHour` was unselected when the gesture began, the entire range is selected.
    /// - If `startHour` was selected when the gesture began, the entire range is deselected.
    /// Does not add or remove `selectedSlotKeys`; hour picks are optional and independent of the grid.
    func toggleHoursInRange(date iso: String, slotIndex: Int, startHour: Int, endHour: Int, initiallySelected: Bool) {
        let lo = min(startHour, endHour)
        let hi = max(startHour, endHour)
        for h in lo...hi {
            let key = makeHourKey(date: iso, slotIndex: slotIndex, hour: h)
            if initiallySelected {
                selectedHourKeys.remove(key)
            } else {
                selectedHourKeys.insert(key)
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

    func hasAnyHours(for iso: String, slotIndex: Int) -> Bool {
        let prefix = "\(iso)#\(slotIndex)#"
        return selectedHourKeys.contains { $0.hasPrefix(prefix) }
    }

    func removeHours(for iso: String, slotIndex: Int) {
        let prefix = "\(iso)#\(slotIndex)#"
        selectedHourKeys = selectedHourKeys.filter { !$0.hasPrefix(prefix) }
    }

    func removeHours(for iso: String) {
        let prefix = "\(iso)#"
        selectedHourKeys = selectedHourKeys.filter { !$0.hasPrefix(prefix) }
    }

    static func linkedDayOptions(pollDays: [String], votes: [Vote]) -> [String] {
        var active: Set<String> = []
        for vote in votes {
            vote.dates.forEach { active.insert($0) }
            (vote.slots ?? []).forEach { active.insert($0.date) }
        }
        return pollDays.filter { active.contains($0) }
    }

    var hasAnyVote: Bool {
        !selectedDates.isEmpty || !selectedSlotKeys.isEmpty
    }

    /// Keeps `focusedDayIso` on a day that exists in the schedule's poll list.
    func syncFocusedDayWithPollDays(_ pollDays: [String]) {
        guard !pollDays.isEmpty else {
            focusedDayIso = ""
            return
        }
        if !pollDays.contains(focusedDayIso) {
            focusedDayIso = pollDays[0]
        }
    }
}

/// Concrete type used by ExpandedWeekView.
typealias WeekVoteDraft = SlotVoteDraft
/// Concrete type used by ExpandedDaysView.
typealias DaysVoteDraft = SlotVoteDraft
