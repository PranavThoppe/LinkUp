import SwiftUI

struct DaysCardView: View {
    let payload: MessagePayload

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LinkUp • Days")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 8)

            if dayColumns.isEmpty {
                Text("No days selected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            } else {
                daysGrid
            }

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(height: 0.5)
                .padding(.top, 8)

            footerView
                .padding(.top, 8)
        }
        .padding(10)
        .background(Theme.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .cornerRadius(12)
    }

    private var daysGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("")
                    .frame(width: 34)
                ForEach(dayColumns, id: \.self) { iso in
                    Text(shortLabel(for: iso))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<slotLabels.count, id: \.self) { slot in
                HStack(spacing: 4) {
                    Text(slotLabels[slot])
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 34, alignment: .leading)

                    ForEach(dayColumns, id: \.self) { iso in
                        let key = slotKey(date: iso, slot: slot)
                        let colors = voterColorsBySlot[key] ?? []
                        let count = colors.count
                        VStack(spacing: 1) {
                            Color.clear.frame(height: 1)
                            VoterDots(colors: colors, maxVisible: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                        .background(VoteHeatmap.color(for: count, maxCount: maxSlotVotes))
                        .cornerRadius(4)
                    }
                }
            }
        }
    }

    private var dayColumns: [String] {
        Array((payload.schedule.specificDates ?? []).prefix(7))
    }

    private var voterColorsBySlot: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes {
            for selection in vote.slots ?? [] {
                let key = slotKey(date: selection.date, slot: selection.slotIndex)
                map[key, default: []].append(vote.senderColor)
            }
        }
        return map
    }

    private var maxSlotVotes: Int {
        max(voterColorsBySlot.values.map(\.count).max() ?? 0, 1)
    }

    private func slotKey(date: String, slot: Int) -> String {
        "\(date)#\(slot)"
    }

    private func shortLabel(for iso: String) -> String {
        guard let (y, m, d) = parseISODate(iso) else { return iso }
        let comps = DateComponents(year: y, month: m + 1, day: d)
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return iso }
        let formatter = DateFormatter()
        formatter.dateFormat = "E d"
        return formatter.string(from: date)
    }

    private var votedParticipants: [Participant] {
        let votedIds = Set(
            payload.votes
                .filter { !($0.slots ?? []).isEmpty || !$0.dates.isEmpty }
                .map { $0.senderId }
        )
        return payload.participants.filter { votedIds.contains($0.id) }
    }

    private var footerView: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Array(votedParticipants.prefix(3).enumerated()), id: \.offset) { _, participant in
                    Circle()
                        .fill(Color(hex: participant.color))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(participant.initial)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                Text(verbatim: "\(votedParticipants.count) voted")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.leading, 2)
            }

            Spacer()

            Text("Tap to vote →")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.primaryBlue)
        }
    }
}
