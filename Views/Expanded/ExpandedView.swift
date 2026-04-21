import SwiftUI

/// Routes to the correct interactive voting view based on the schedule mode.
struct ExpandedView: View {
    let payload: MessagePayload
    let selfSenderId: String
    var monthVoteDraft: MonthVoteDraft? = nil
    var weekVoteDraft: WeekVoteDraft? = nil
    var daysVoteDraft: DaysVoteDraft? = nil
    let onDone: (MessagePayload) -> Void
    var onCollapseToCompact: (() -> Void)? = nil

    var body: some View {
        switch payload.schedule.mode {
        case .month:
            let draft = monthVoteDraft ?? MonthVoteDraft(payload: payload, selfSenderId: selfSenderId)
            ExpandedCalendarView(
                payload: payload,
                selfSenderId: selfSenderId,
                voteDraft: draft,
                onDone: onDone,
                onCollapseToCompact: onCollapseToCompact
            )
        case .week:
            let draft = weekVoteDraft ?? WeekVoteDraft(payload: payload, selfSenderId: selfSenderId)
            ExpandedWeekView(
                payload: payload,
                selfSenderId: selfSenderId,
                voteDraft: draft,
                onDone: onDone
            )
        case .days:
            let draft = daysVoteDraft ?? DaysVoteDraft(payload: payload, selfSenderId: selfSenderId)
            ExpandedDaysView(
                payload: payload,
                selfSenderId: selfSenderId,
                voteDraft: draft,
                onDone: onDone
            )
        }
    }
}
