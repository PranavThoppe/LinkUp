import SwiftUI

struct CalendarCardView: View {
    let payload: MessagePayload
    var selfSenderId: String? = nil

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

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
        let iso = cell.inMonth ? toISODate(year: month.year, month: month.month, day: cell.day) : ""
        let voters = cell.inMonth ? (voterColorsByDate[iso] ?? []) : []
        let bgColor = VoteHeatmap.color(for: voters.count, maxCount: maxDateVotes)

        VStack(spacing: 0) {
            // Date badge — vote color on badge only, not the whole cell
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
                    .frame(width: 28, height: 28)
                Text(verbatim: "\(cell.day)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .opacity(cell.inMonth ? 1.0 : 0.45)

            // Dot row — always reserve height so rows stay uniform
            VoterDots(colors: voters, maxVisible: 3)
                .frame(height: 14)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
                    .foregroundColor(Theme.textSecondary)
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
        max(voterColorsByDate.values.map(\.count).max() ?? 0, 1)
    }

    private var votedParticipants: [Participant] {
        let votedIds = Set(payload.votes.filter { !$0.dates.isEmpty }.map { $0.senderId })
        return payload.participants.filter { votedIds.contains($0.id) }
    }

}
