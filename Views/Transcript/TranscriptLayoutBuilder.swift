import Messages
import SwiftUI
import UIKit

enum TranscriptLayoutBuilder {
    // Card dimensions used for both the rendered image and (if live layout is
    // re-introduced later) for preferredContentSize.
    static let monthCardSize = CGSize(width: 300, height: 390)
    static let compactCardSize = CGSize(width: 300, height: 260)

    /// Returns an `MSMessageTemplateLayout` whose image is a pixel-perfect
    /// snapshot of the card view for the given payload.
    ///
    /// `MSMessageLiveLayout` was evaluated but abandoned: in transcript mode
    /// `conversation.selectedMessage` is always nil (the framework fires
    /// `willBecomeActive` once per visible live-layout bubble with no way to
    /// identify which message each invocation belongs to). A static template
    /// image is reliable and sufficient until a shared data store is added.
    @MainActor
    static func makeLayout(for payload: MessagePayload) -> MSMessageLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = renderCardImage(for: payload)
        return layout
    }

    // MARK: - Image rendering

    /// Renders a card view to a `UIImage` using SwiftUI's `ImageRenderer`.
    /// Unlike the previous `UIHostingController` + `drawHierarchy` approach,
    /// `ImageRenderer` does not require the view to be in a live window, which
    /// avoids the "Snapshotting a view not in a visible window" warning and the
    /// resulting black images.
    @MainActor
    private static func renderCardImage(for payload: MessagePayload) -> UIImage? {
        switch payload.schedule.mode {
        case .month:
            let view = CalendarCardView(payload: payload)
                .frame(width: monthCardSize.width, height: monthCardSize.height)
            return render(view, scale: 2)
        case .week:
            let view = WeekCardView(payload: payload)
                .frame(width: compactCardSize.width, height: compactCardSize.height)
            return render(view, scale: 2)
        case .days:
            let view = DaysCardView(payload: payload)
                .frame(width: compactCardSize.width, height: compactCardSize.height)
            return render(view, scale: 2)
        }
    }

    @MainActor
    private static func render<V: View>(_ view: V, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }
}
