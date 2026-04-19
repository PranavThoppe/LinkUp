import SwiftUI

/// Tappable slot grid shared by ExpandedWeekView and ExpandedDaysView.
///
/// Columns are ISO date strings. Each cell is keyed `"date#slotIndex"`.
/// Self-selected cells render blue; others' votes render as a green heatmap.
struct VoteToggleGrid: View {
    let dayColumns: [String]
    let slotLabels: [String]
    @Binding var selectedSlots: Set<String>
    /// Per-slot voter colors from OTHER participants (excluding self), keyed `"date#slotIndex"`.
    let otherVoterSlots: [String: [String]]

    var body: some View {
        VStack(spacing: 5) {
            // Column headers
            HStack(spacing: 3) {
                Text("")
                    .frame(width: 40)
                ForEach(dayColumns, id: \.self) { iso in
                    columnHeader(iso: iso)
                }
            }
            .padding(.bottom, 2)

            // Slot rows
            ForEach(0..<slotLabels.count, id: \.self) { slotIdx in
                HStack(spacing: 3) {
                    Text(slotLabels[slotIdx])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, alignment: .leading)

                    ForEach(dayColumns, id: \.self) { iso in
                        slotCell(date: iso, slotIndex: slotIdx)
                    }
                }
            }
        }
    }

    // MARK: - Column header

    @ViewBuilder
    private func columnHeader(iso: String) -> some View {
        if let parts = transcriptDayColumnParts(iso: iso) {
            VStack(spacing: 2) {
                Text(parts.weekday)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text(verbatim: "\(parts.day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        } else {
            Text(iso)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Slot cell

    @ViewBuilder
    private func slotCell(date: String, slotIndex: Int) -> some View {
        let key = "\(date)#\(slotIndex)"
        let isSelf = selectedSlots.contains(key)
        let otherColors = otherVoterSlots[key] ?? []
        let bgColor: Color = isSelf
            ? Theme.primaryBlue
            : (otherColors.isEmpty
                ? Theme.cellDefault
                : VoteHeatmap.color(for: otherColors.count, maxCount: maxOtherVotes))

        Button {
            var next = selectedSlots
            if next.contains(key) {
                next.remove(key)
            } else {
                next.insert(key)
            }
            selectedSlots = next
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(bgColor)
                if !otherColors.isEmpty && !isSelf {
                    VoterDots(colors: otherColors, maxVisible: 2)
                        .padding(.bottom, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private var maxOtherVotes: Int {
        max(otherVoterSlots.values.map(\.count).max() ?? 0, 1)
    }
}
