import SwiftUI

struct CalendarCardView: View {
    let payload: MessagePayload
    var selfSenderId: String? = nil

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var scheduleEligiblePollDates: Set<String>? {
        payload.schedule.eligiblePollDates
    }

    private func isInEligiblePoll(iso: String) -> Bool {
        scheduleEligiblePollDates?.contains(iso) ?? true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, 8)

            ZStack {
                if let month = displayMonth {
                    monthGrid(month)
                }
                TranscriptTapCallout(hasVoted: tapCalloutHasVoted)
            }

            Rectangle()
                .fill(Theme.cardDivider)
                .frame(height: 0.5)
                .padding(.top, 8)
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

    // MARK: - Header

    private var headerView: some View {
        Group {
            if let month = displayMonth {
                Text(monthHeaderTitle(for: month))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("LinkUp")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private func monthGrid(_ month: MonthYear) -> some View {
        let grid = buildMonthGridSunFirst(month: month.month, year: month.year)
        let rows = stride(from: 0, to: grid.count, by: 7)
            .map { Array(grid[$0..<min($0 + 7, grid.count)]) }

        VStack(spacing: 0) {
            // Day-of-week header row
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)

            // Day rows
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                        dayCell(cell: rows[rowIndex][colIndex], month: month)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(cell: CalendarCell, month: MonthYear) -> some View {
        if cell.inMonth {
            let iso = toISODate(year: month.year, month: month.month, day: cell.day)
            let inPoll = isInEligiblePoll(iso: iso)
            let voters = inPoll ? (voterColorsByDate[iso] ?? []) : []
            let bgColor = inPoll
                ? VoteHeatmap.color(for: voters.count, maxCount: maxDateVotes)
                : Theme.cellDefault.opacity(0.28)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bgColor)
                        .frame(width: 28, height: 28)
                    Text(verbatim: "\(cell.day)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(inPoll ? .white : Theme.textSecondary.opacity(0.55))
                        .strikethrough(!inPoll, color: Theme.textSecondary.opacity(0.65))
                }

                VoterDots(colors: voters, maxVisible: 3)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.cellDefault)
                        .frame(width: 28, height: 28)
                        .opacity(0.45)
                    Text(verbatim: "\(cell.day)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .opacity(0.45)

                VoterDots(colors: [], maxVisible: 3)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer

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

    // MARK: - Computed

    private var displayMonth: MonthYear? {
        payload.schedule.months?.first
    }

    private func monthHeaderTitle(for month: MonthYear) -> String {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        if month.year == currentYear {
            return monthName(month.month)
        }
        // Use verbatim formatting to avoid locale adding separators in year.
        return "\(monthName(month.month)) \(String(month.year))"
    }

    private var voterColorsByDate: [String: [String]] {
        var map: [String: [String]] = [:]
        for vote in payload.votes {
            for date in vote.dates {
                map[date, default: []].append(vote.senderColor)
            }
        }
        return map
    }

    private var maxDateVotes: Int {
        let allowed = scheduleEligiblePollDates
        let relevant = voterColorsByDate.filter { allowed == nil || allowed!.contains($0.key) }
        return max(relevant.values.map(\.count).max() ?? 0, 1)
    }

    private var votedParticipants: [Participant] {
        let votedIds = Set(payload.votes.filter { !$0.dates.isEmpty }.map { $0.senderId })
        return payload.participants.filter { votedIds.contains($0.id) }
    }

}
