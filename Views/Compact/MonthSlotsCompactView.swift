import SwiftUI

struct MonthSlotsCompactView: View {
    let payload: MessagePayload
    let selfSenderId: String
    @ObservedObject var voteDraft: MonthVoteDraft
    let onSave: (MessagePayload) -> Void
    let onExpand: () -> Void

    /// How far the user has dragged upward (points); used for progress and label offset.
    @State private var swipeUpDragMagnitude: CGFloat = 0

    private let expandSwipeUpThreshold: CGFloat = 56

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    private var sortedDates: [String] {
        voteDraft.sortedDates
    }

    private var focusedDayColumns: [String] {
        voteDraft.focusedDayIso.isEmpty ? [] : [voteDraft.focusedDayIso]
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)

            if sortedDates.isEmpty {
                emptyState
            } else {
                content
            }

            saveButton
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(Theme.background)
        .onAppear {
            voteDraft.syncFocusedDayWithSelection()
        }
        .onChange(of: sortedDates) { _, _ in
            voteDraft.syncFocusedDayWithSelection()
        }
    }

    private var toolbar: some View {
        // progress 0 → 1 as user drags up toward activation threshold
        let progress = min(max(swipeUpDragMagnitude / expandSwipeUpThreshold, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            if let title = payload.schedule.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            ZStack {
                Text("Swipe up for calendar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.primaryBlue)
                    .opacity(1)
               
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .offset(y: -swipeUpDragMagnitude * 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onExpand() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens expanded calendar view")
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let dy = value.translation.height
                    let dominantlyVertical = abs(dy) > abs(value.translation.width) * 0.85
                    if dy < 0 && dominantlyVertical {
                        swipeUpDragMagnitude = -dy
                    } else {
                        swipeUpDragMagnitude = 0
                    }
                }
                .onEnded { value in
                    let dy = value.translation.height
                    let dominantlyVertical = abs(dy) > abs(value.translation.width) * 0.85
                    if dy <= -expandSwipeUpThreshold && dominantlyVertical {
                        onExpand()
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        swipeUpDragMagnitude = 0
                    }
                }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Pick days in expanded view first.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Button("Open Expanded View") {
                onExpand()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.primaryBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var content: some View {
        VStack(spacing: 10) {
            Picker("Day", selection: $voteDraft.focusedDayIso) {
                ForEach(sortedDates, id: \.self) { iso in
                    Text(slotPickerTitle(iso)).tag(iso)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your availability")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                VoteToggleGrid(
                    dayColumns: focusedDayColumns,
                    slotLabels: slotLabels,
                    selectedSlots: $voteDraft.selectedSlotKeys,
                    otherVoterSlots: [:],
                    orientation: .slotsOnXAxis
                )
            }

            Text("This view only shows your votes. Leave all slots empty for no time preference.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var saveButton: some View {
        Button {
            onSave(
                buildUpdatedMonthPayload(
                    payload: payload,
                    selfSenderId: selfSenderId,
                    selectedDates: voteDraft.selectedDates,
                    selectedSlotKeys: voteDraft.selectedSlotKeys
                )
            )
        } label: {
            Text("Save")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(sortedDates.isEmpty ? Theme.primaryBlue.opacity(0.4) : Theme.primaryBlue)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(sortedDates.isEmpty)
    }

    private func slotPickerTitle(_ iso: String) -> String {
        guard let parts = transcriptDayColumnParts(iso: iso) else { return iso }
        return "\(parts.weekday) \(parts.day) · \(monthNameFromIso(iso))"
    }

    private func monthNameFromIso(_ iso: String) -> String {
        guard let (_, m, _) = parseISODate(iso) else { return "" }
        return monthName(m)
    }
}
