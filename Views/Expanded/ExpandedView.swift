import SwiftUI

/// Routes to the correct interactive voting view based on the schedule mode.
struct ExpandedView: View {
    let payload: MessagePayload
    let selfSenderId: String
    let onDone: (MessagePayload) -> Void

    var body: some View {
        switch payload.schedule.mode {
        case .month:
            ExpandedCalendarView(payload: payload, selfSenderId: selfSenderId, onDone: onDone)
        case .week:
            ExpandedWeekView(payload: payload, selfSenderId: selfSenderId, onDone: onDone)
        case .days:
            ExpandedDaysView(payload: payload, selfSenderId: selfSenderId, onDone: onDone)
        }
    }
}
