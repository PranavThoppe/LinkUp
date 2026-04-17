import SwiftUI

struct DaysCardView: View {
    let payload: MessagePayload
    var selfSenderId: String? = nil

    private let slotLabels = ["Morn", "Aftn", "Eve", "Night"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(scheduleTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            if dayColumns.isEmpty {
                Text("No days selected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                daysGrid
            }

            Rectangle()
                .fill(Theme.cardBorder)
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
        .overlay(alignment: .bottom) {
            if let selfId = selfSenderId {
                VoteBanner(hasVoted: selfHasVoted(selfId: selfId))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        .cornerRadius(16)
    }

    private var daysGrid: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Text("")
                    .frame(width: 36)
                ForEach(dayColumns, id: \.self) { iso in
                    Text(shortLabel(for: iso))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(0..<slotLabels.count, id: \.self) { slot in
                HStack(spacing: 3) {
                    Text(slotLabels[slot])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, alignment: .leading)

                    ForEach(dayColumns, id: \.self) { iso in
                        let key = slotKey(date: iso, slot: slot)
                        let colors = voterColorsBySlot[key] ?? []
                        let count = colors.count
                        ZStack {
                            VoterDots(colors: colors, maxVisible: 2)
                            if colors.isEmpty {
                                slotPlaceholderDots
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .background(slotCellBackground(voteCount: count))
                        .cornerRadius(5)
                    }
                }
            }
        }
    }

    /// Title from selected days: `Schedule • April` or `Schedule • April & May` across months.
    private var scheduleTitle: String {
        let parts = scheduleTitleMonthParts()
        if parts.isEmpty { return "Schedule" }
        return "Schedule • " + parts.joined(separator: " & ")
    }

    private func scheduleTitleMonthParts() -> [String] {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        var seenKeys = Set<String>()
        var parts: [String] = []
        for iso in dayColumns {
            guard let (year, month, _) = parseISODate(iso) else { continue }
            let key = "\(year)-\(month)"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            if year == currentYear {
                parts.append(monthName(month))
            } else {
                parts.append("\(monthName(month)) \(String(year))")
            }
        }
        return parts
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

    private func slotCellBackground(voteCount: Int) -> Color {
        if voteCount > 0 {
            VoteHeatmap.color(for: voteCount, maxCount: maxSlotVotes)
        } else {
            Theme.cellDefault
        }
    }

    private var slotPlaceholderDots: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 5, height: 5)
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 5, height: 5)
        }
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

    private func selfHasVoted(selfId: String) -> Bool {
        payload.votes.contains { $0.senderId == selfId && (!($0.slots ?? []).isEmpty || !$0.dates.isEmpty) }
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

            Spacer()

            Text("Tap to vote →")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.messageBubbleBlue)
        }
    }
}
