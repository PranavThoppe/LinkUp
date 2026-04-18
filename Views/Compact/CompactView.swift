import SwiftUI

struct CompactView: View {
    /// Called when the user taps "Send Schedule". Provides the fully-built Schedule.
    let onSend: (Schedule) -> Void
    @ObservedObject var draft: ComposerDraft
    /// True when picker content should allow full scrolling (expanded mode).
    let isScrollable: Bool

    @FocusState private var isTitleFieldFocused: Bool

    private var canSend: Bool {
        switch draft.selectedTab {
        case .month: return !draft.selectedMonths.isEmpty
        case .week:
            guard let start = draft.weekStartIso, let end = draft.weekEndIso else { return false }
            return start <= end
        case .days:  return !draft.selectedDatesIso.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            if isScrollable {
                // Title input is shown only in expanded mode where keyboard space is available.
                titleInput
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            // Content
            Group {
                switch draft.selectedTab {
                case .month:
                    CompactMonthPicker(selectedMonths: $draft.selectedMonths, isScrollable: isScrollable)
                case .week:
                    CompactWeekPicker(startIso: $draft.weekStartIso, endIso: $draft.weekEndIso, isScrollable: isScrollable)
                case .days:
                    CompactDaysPicker(selectedDatesIso: $draft.selectedDatesIso)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .padding(.horizontal, 14)
            .simultaneousGesture(TapGesture().onEnded { isTitleFieldFocused = false })

            // Send button
            sendButton
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .simultaneousGesture(TapGesture().onEnded { isTitleFieldFocused = false })
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
        .simultaneousGesture(TapGesture().onEnded { isTitleFieldFocused = false })
    }

    private var titleInput: some View {
        TextField(
            "",
            text: $draft.scheduleTitle,
            prompt: Text("Title").foregroundColor(.white.opacity(0.7))
        )
        .focused($isTitleFieldFocused)
        .textInputAutocapitalization(.sentences)
        .autocorrectionDisabled(false)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func tabButton(_ mode: ScheduleMode) -> some View {
        let isActive = draft.selectedTab == mode
        Button {
            draft.selectedTab = mode
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
        let trimmedTitle = draft.scheduleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // Derive creatorId: will be replaced with real senderId in MessagesViewController
        return Schedule(
            id: UUID(),
            creatorId: "",   // filled in by MessagesViewController using localParticipantIdentifier
            mode: draft.selectedTab,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            months: draft.selectedTab == .month ? draft.selectedMonths : nil,
            weekRange: draft.selectedTab == .week
                ? (draft.weekStartIso.map { s in DateRange(startIso: s, endIso: draft.weekEndIso ?? s) })
                : nil,
            specificDates: draft.selectedTab == .days ? draft.selectedDatesIso : nil,
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
