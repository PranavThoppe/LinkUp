import Messages
import SwiftUI
import UIKit

enum TranscriptLayoutBuilder {
    static func makeLayout(for payload: MessagePayload) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()

        if let image = renderCardImage(for: payload) {
            layout.image = image
        }
        return layout
    }

    private static func subtitle(for schedule: Schedule) -> String {
        switch schedule.mode {
        case .month:
            let count = schedule.months?.count ?? 0
            return "\(count) month\(count == 1 ? "" : "s")"
        case .week:
            return "Week availability"
        case .days:
            let count = schedule.specificDates?.count ?? 0
            return "\(count) day\(count == 1 ? "" : "s")"
        }
    }

    private static func renderCardImage(for payload: MessagePayload) -> UIImage? {
        let cardView: AnyView
        let cardSize: CGSize
        switch payload.schedule.mode {
        case .month:
            cardView = AnyView(
                CalendarCardView(payload: payload)
                    .frame(width: 450, height: 480)
            )
            cardSize = CGSize(width: 450, height: 480)
        case .week:
            cardView = AnyView(WeekCardView(payload: payload))
            cardSize = CGSize(width: 300, height: 260)
        case .days:
            cardView = AnyView(DaysCardView(payload: payload))
            cardSize = CGSize(width: 300, height: 260)
        }

        let host = UIHostingController(rootView: cardView)
        host.view.backgroundColor = UIColor(red: 28/255.0, green: 28/255.0, blue: 30/255.0, alpha: 1.0)
        host.view.frame = CGRect(origin: .zero, size: cardSize)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}
