import SwiftUI

struct CompactView: View {
    /// Called when the user taps "Send Schedule". Provides the fully-built Schedule.
    let onSend: (Schedule) -> Void
    /// True when picker content should allow full scrolling (expanded mode).
    let isScrollable: Bool

    @State private var selectedTab: ScheduleMode = .month

    // Month state
    @State private var selectedMonths: [MonthYear] = {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        return [MonthYear(month: cal.component(.month, from: now) - 1, year: cal.component(.year, from: now))]
    }()

    // Week state
    @State private var weekStartIso: String? = nil
    @State private var weekEndIso: String? = nil

    // Days state
    @State private var selectedDatesIso: [String] = []

    private var canSend: Bool {
        switch selectedTab {
        case .month: return !selectedMonths.isEmpty
        case .week:  return weekStartIso != nil && weekEndIso != nil && weekStartIso! <= weekEndIso!
        case .days:  return !selectedDatesIso.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            // Content
            Group {
                switch selectedTab {
                case .month:
                    CompactMonthPicker(selectedMonths: $selectedMonths, isScrollable: isScrollable)
                case .week:
                    CompactWeekPicker(startIso: $weekStartIso, endIso: $weekEndIso, isScrollable: isScrollable)
                case .days:
                    CompactDaysPicker(selectedDatesIso: $selectedDatesIso)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)

            // Send button
            sendButton
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(Theme.background)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleMode.allCases, id: \.self) { mode in
                tabButton(mode)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabButton(_ mode: ScheduleMode) -> some View {
        let isActive = selectedTab == mode
        Button {
            selectedTab = mode
        } label: {
            VStack(spacing: 8) {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isActive ? .white : Theme.textSecondary)

                Rectangle()
                    .fill(isActive ? Theme.primaryBlue : Color.clear)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(1)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Send button

    private var sendButton: some View {
        Button {
            guard canSend else { return }
            let schedule = buildSchedule()
            onSend(schedule)
        } label: {
            Text("Send Schedule")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(canSend ? Theme.primaryBlue : Theme.primaryBlue.opacity(0.4))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    // MARK: - Build Schedule

    private func buildSchedule() -> Schedule {
        let now = Date()
        // Derive creatorId: will be replaced with real senderId in MessagesViewController
        return Schedule(
            id: UUID(),
            creatorId: "",   // filled in by MessagesViewController using localParticipantIdentifier
            mode: selectedTab,
            title: nil,
            months: selectedTab == .month ? selectedMonths : nil,
            weekRange: selectedTab == .week
                ? (weekStartIso.map { s in DateRange(startIso: s, endIso: weekEndIso ?? s) })
                : nil,
            specificDates: selectedTab == .days ? selectedDatesIso : nil,
            createdAt: now,
            updatedAt: now,
            isActive: true
        )
    }
}

// MARK: - Display names

extension ScheduleMode {
    var displayName: String {
        switch self {
        case .month: return "Month"
        case .week:  return "Week"
        case .days:  return "Days"
        }
    }
}
