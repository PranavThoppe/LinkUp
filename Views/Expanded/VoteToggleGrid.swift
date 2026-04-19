import SwiftUI

enum VoteGridOrientation {
    case daysOnXAxis
    case slotsOnXAxis
}

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
    var isInteractive: Bool = true
    var orientation: VoteGridOrientation = .daysOnXAxis

    var body: some View {
        Group {
            if orientation == .daysOnXAxis {
                daysXAxisGrid
            } else {
                slotsXAxisGrid
            }
        }
    }

    private var daysXAxisGrid: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Text("")
                    .frame(width: 40)
                ForEach(dayColumns, id: \.self) { iso in
                    columnHeader(iso: iso)
                }
            }
            .padding(.bottom, 2)

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

    private var slotsXAxisGrid: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Text("")
                    .frame(width: 64)
                ForEach(0..<slotLabels.count, id: \.self) { slotIdx in
                    Text(slotLabels[slotIdx])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(dayColumns, id: \.self) { iso in
                HStack(spacing: 3) {
                    rowHeader(iso: iso)
                        .frame(width: 64, alignment: .leading)
                    ForEach(0..<slotLabels.count, id: \.self) { slotIdx in
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

    @ViewBuilder
    private func rowHeader(iso: String) -> some View {
        if let parts = transcriptDayColumnParts(iso: iso) {
            VStack(alignment: .leading, spacing: 2) {
                Text(parts.weekday)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text(verbatim: "\(parts.day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        } else {
            Text(iso)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
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

        Group {
            if isInteractive {
                Button {
                    var next = selectedSlots
                    if next.contains(key) {
                        next.remove(key)
                    } else {
                        next.insert(key)
                    }
                    selectedSlots = next
                } label: {
                    slotCellBody(bgColor: bgColor, otherColors: otherColors, isSelf: isSelf)
                }
                .buttonStyle(.plain)
            } else {
                slotCellBody(bgColor: bgColor, otherColors: otherColors, isSelf: isSelf)
            }
        }
    }

    private func slotCellBody(bgColor: Color, otherColors: [String], isSelf: Bool) -> some View {
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

    private var maxOtherVotes: Int {
        max(otherVoterSlots.values.map(\.count).max() ?? 0, 1)
    }
}
