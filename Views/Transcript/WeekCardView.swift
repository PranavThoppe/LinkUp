import SwiftUI

struct WeekCardView: View {
    let payload: MessagePayload
    var selfSenderId: String? = nil

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TranscriptCompactScheduleHeaderView(metrics: compactHeaderMetrics)
                .padding(.bottom, compactHeaderMetrics.hasVisibleHeaderContent ? 10 : 0)

            ZStack {
                if dayColumns.isEmpty {
                    Text("No week range selected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    weekGrid
                }
                TranscriptTapCallout(hasVoted: tapCalloutHasVoted)
            }

            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)
                .padding(.top, 10)

            footerView
                .padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tapCalloutHasVoted: Bool {
        guard let id = selfSenderId else { return false }
        return payload.hasVote(from: id)
    }

    private var weekGrid: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Text("")
                    .frame(width: 36)
                ForEach(dayColumns, id: \.self) { iso in
                    dayColumnHeader(iso: iso)
                }
            }
            .padding(.bottom, 2)

            ForEach(0..<slotLabels.count, id: \.self) { slot in
                HStack(spacing: 3) {
                    Text(slotLabels[slot])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, alignment: .leading)

                    ForEach(dayColumns, id: \.self) { iso in
                        let key = slotKey(date: iso, slot: slot)
                        let count = voterColorsBySlot[key]?.count ?? 0
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(slotCellBackground(voteCount: count))
                            .cornerRadius(5)
                    }
                }
            }
        }
    }

    private var compactHeaderMetrics: TranscriptCompactHeaderMetrics {
        TranscriptCompactHeaderMetrics(
            headline: TranscriptCompactScheduleHeader.headline(for: payload.schedule),
            monthParts: TranscriptCompactScheduleHeader.monthParts(from: dayColumns)
        )
    }

    private var dayColumns: [String] {
        guard let range = payload.schedule.weekRange else { return [] }
        return dateRangeInclusive(startIso: range.startIso, endIso: range.endIso)
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

    /// Visible slot chrome: neutral fill when empty, heatmap when there are votes.
    private func slotCellBackground(voteCount: Int) -> Color {
        if voteCount > 0 {
            VoteHeatmap.color(for: voteCount, maxCount: maxSlotVotes)
        } else {
            Theme.cellDefault
        }
    }

    @ViewBuilder
    private func dayColumnHeader(iso: String) -> some View {
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
        }
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
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(participant.initial)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                Text(verbatim: "\(votedParticipants.count) voted")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.leading, 2)
            }
        }
    }
}
