import Messages
import SwiftUI
import UIKit

enum TranscriptLayoutBuilder {
    // Card dimensions used for both the rendered image and (if live layout is
    // re-introduced later) for preferredContentSize.
    static let monthCardSize = CGSize(width: 320, height: 410)
    static let compactCardWidth: CGFloat = 300
    /// Default height when the compact header fits one line; actual snapshot height uses `compactCardSize(for:)`.
    static let compactCardDefaultHeight: CGFloat = 240

    /// Raster scale for transcript snapshots — match the device so 3× phones get 3× pixels (sharper than a fixed 2× bitmap).
    private static var transcriptSnapshotScale: CGFloat {
        let s = UITraitCollection.current.displayScale
        return s > 0 ? s : 2
    }

    /// Width used to render the month-mode transcript card.
    ///
    /// On standard-width phones the historical 320 pt canvas is kept.
    /// On wider displays (Pro Max and above, logical width > 390 pt) the canvas
    /// expands to match the available bubble width so `MSMessageTemplateLayout`
    /// does not need to upscale the raster image — preventing thin elements like
    /// strikethrough lines from appearing thicker than intended.
    private static var adaptiveMonthCardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        guard screenWidth > 390 else { return monthCardSize.width }
        // Subtract ~50 pt for typical bubble side margins; cap at 380 pt to
        // stay comfortably within the bubble safe-area on all current iPhones.
        return min(screenWidth - 50, 380)
    }

    /// Returns an `MSMessageTemplateLayout` whose image is a pixel-perfect
    /// snapshot of the card view for the given payload.
    ///
    /// `MSMessageLiveLayout` was evaluated but abandoned: in transcript mode
    /// `conversation.selectedMessage` is always nil (the framework fires
    /// `willBecomeActive` once per visible live-layout bubble with no way to
    /// identify which message each invocation belongs to). A static template
    /// image is reliable and sufficient until a shared data store is added.
    /// - Parameter viewerParticipantId: `MSConversation.localParticipantIdentifier` for vote-aware
    ///   transcript art ("Tap to vote" vs "Tap to view"). When `nil`, the callout defaults to "Tap to vote".
    @MainActor
    static func makeLayout(for payload: MessagePayload, viewerParticipantId: String? = nil) -> MSMessageLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = renderCardImage(for: payload, viewerParticipantId: viewerParticipantId)
        return layout
    }

    // MARK: - Image rendering

    /// Renders a card view to a `UIImage` using SwiftUI's `ImageRenderer`.
    /// Unlike the previous `UIHostingController` + `drawHierarchy` approach,
    /// `ImageRenderer` does not require the view to be in a live window, which
    /// avoids the "Snapshotting a view not in a visible window" warning and the
    /// resulting black images.
    @MainActor
    private static func renderCardImage(for payload: MessagePayload, viewerParticipantId: String?) -> UIImage? {
        switch payload.schedule.mode {
        case .month:
            let cardWidth = adaptiveMonthCardWidth
            let view = CalendarCardView(payload: payload, selfSenderId: viewerParticipantId)
                .frame(width: cardWidth, height: monthCardSize.height)
            return render(view, scale: transcriptSnapshotScale)
        case .week:
            let size = Self.compactCardSize(for: payload)
            let view = WeekCardView(payload: payload, selfSenderId: viewerParticipantId)
                .frame(width: size.width, height: size.height)
            return render(view, scale: transcriptSnapshotScale)
        case .days:
            let size = Self.compactCardSize(for: payload)
            let view = DaysCardView(payload: payload, selfSenderId: viewerParticipantId)
                .frame(width: size.width, height: size.height)
            return render(view, scale: transcriptSnapshotScale)
        }
    }

    @MainActor
    private static func render<V: View>(_ view: V, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }

    /// Week/days transcript snapshot size: width fixed, height grows when the header wraps.
    private static func compactCardSize(for payload: MessagePayload) -> CGSize {
        let headline = TranscriptCompactScheduleHeader.headline(for: payload.schedule)
        let metrics = TranscriptCompactHeaderMetrics(headline: headline, monthParts: [])
        return CGSize(width: compactCardWidth, height: metrics.compactCardHeight)
    }
}
