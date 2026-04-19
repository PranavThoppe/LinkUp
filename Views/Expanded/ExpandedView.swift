import SwiftUI

/// Routes to the correct interactive voting view based on the schedule mode.
struct ExpandedView: View {
    let payload: MessagePayload
    let selfSenderId: String
    var monthVoteDraft: MonthVoteDraft? = nil
    let onDone: (MessagePayload) -> Void
    var onCollapseToCompact: (() -> Void)? = nil

    var body: some View {
        switch payload.schedule.mode {
        case .month:
            if let monthVoteDraft {
                ExpandedCalendarView(
                    payload: payload,
                    selfSenderId: selfSenderId,
                    voteDraft: monthVoteDraft,
                    onDone: onDone,
                    onCollapseToCompact: onCollapseToCompact
                )
            } else {
                ExpandedCalendarView(
                    payload: payload,
                    selfSenderId: selfSenderId,
                    voteDraft: MonthVoteDraft(payload: payload, selfSenderId: selfSenderId),
                    onDone: onDone,
                    onCollapseToCompact: onCollapseToCompact
                )
            }
        case .week:
            ExpandedWeekView(payload: payload, selfSenderId: selfSenderId, onDone: onDone)
        case .days:
            ExpandedDaysView(payload: payload, selfSenderId: selfSenderId, onDone: onDone)
        }
    }
}
