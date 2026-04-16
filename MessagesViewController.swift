import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    // MARK: - State

    /// The decoded payload from the currently selected message, if any.
    private var activePayload: MessagePayload?

    /// The senderId for the local participant in this conversation.
    private var selfSenderId: String = ""

    // MARK: - Hosted SwiftUI controller

    private var hostedController: UIViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.background)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)

        selfSenderId = conversation.localParticipantIdentifier.uuidString

        if let selectedMessage = conversation.selectedMessage,
           let url = selectedMessage.url {
            switch PayloadCoder.decode(url: url) {
            case .success(let payload):
                activePayload = payload
            case .unsupportedVersion(let v):
                showUnsupportedVersionUI(version: v)
                return
            case .notLinkUp:
                activePayload = nil
            }
        } else {
            activePayload = nil
        }

        presentUI(for: presentationStyle, conversation: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
    }

    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
    }

    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        super.didCancelSending(message, conversation: conversation)
    }

    // MARK: - Presentation style transitions

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        removeHostedController()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
        presentUI(for: presentationStyle, conversation: conversation)
    }

    // MARK: - UI routing

    private func presentUI(for style: MSMessagesAppPresentationStyle, conversation: MSConversation) {
        switch style {
        case .compact:
            presentCompactView(conversation: conversation)
        case .expanded:
            presentExpandedView(conversation: conversation)
        case .transcript:
            break   // Transcript is handled by MSMessageTemplateLayout; no SwiftUI needed here.
        @unknown default:
            break
        }
    }

    // MARK: - Compact (creation)

    private func presentCompactView(conversation: MSConversation) {
        let compactView = CompactView(
            onSend: { [weak self] schedule in
                self?.sendSchedule(schedule, conversation: conversation)
            },
            isScrollable: false
        )
        embed(SwiftUI: compactView)
    }

    private func sendSchedule(_ partialSchedule: Schedule, conversation: MSConversation) {
        // Fill in the creatorId now that we have a real selfSenderId
        let schedule = Schedule(
            id: partialSchedule.id,
            creatorId: selfSenderId,
            mode: partialSchedule.mode,
            title: partialSchedule.title,
            months: partialSchedule.months,
            weekRange: partialSchedule.weekRange,
            specificDates: partialSchedule.specificDates,
            createdAt: partialSchedule.createdAt,
            updatedAt: Date(),
            isActive: partialSchedule.isActive
        )

        let selfInitial = deriveInitial(from: selfSenderId)
        let selfColor = Participant.color(for: 0)

        let selfParticipant = Participant(
            id: selfSenderId,
            initial: selfInitial,
            color: selfColor
        )

        let payload = MessagePayload(
            version: MessagePayload.currentVersion,
            schedule: schedule,
            votes: [],
            participants: [selfParticipant],
            revision: 0,
            lastWriterId: selfSenderId
        )

        guard let url = try? PayloadCoder.encode(payload) else { return }

        let message = MSMessage(session: MSSession())
        message.url = url
        message.summaryText = summaryText(for: schedule)

        let layout = MSMessageTemplateLayout()
        layout.caption = "LinkUp"
        layout.subcaption = schedule.mode.displayName + " schedule"
        message.layout = layout

        conversation.insert(message) { [weak self] error in
            if error == nil {
                self?.dismiss()
            }
        }
    }

    // MARK: - Expanded (creation)

    private func presentExpandedView(conversation: MSConversation) {
        let expandedView = CompactView(
            onSend: { [weak self] schedule in
                self?.sendSchedule(schedule, conversation: conversation)
            },
            isScrollable: true
        )
        embed(SwiftUI: expandedView)
    }

    // MARK: - Unsupported version fallback

    private func showUnsupportedVersionUI(version: Int) {
        let fallback = VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.primaryBlue)
            Text("Update LinkUp")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("This schedule was created with a newer version of LinkUp. Please update the app to view it.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        embed(SwiftUI: fallback)
    }

    // MARK: - SwiftUI embedding helpers

    private func embed<Content: View>(SwiftUI content: Content) {
        removeHostedController()
        let host = UIHostingController(rootView: content)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = UIColor(Theme.background)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
        hostedController = host
    }

    private func removeHostedController() {
        hostedController?.willMove(toParent: nil)
        hostedController?.view.removeFromSuperview()
        hostedController?.removeFromParent()
        hostedController = nil
    }

    // MARK: - Helpers

    private func deriveInitial(from senderId: String) -> String {
        guard let first = senderId.first else { return "?" }
        return String(first).uppercased()
    }

    private func summaryText(for schedule: Schedule) -> String {
        switch schedule.mode {
        case .month:
            let count = schedule.months?.count ?? 0
            return "LinkUp: \(count) month\(count == 1 ? "" : "s") – tap to vote"
        case .week:
            return "LinkUp: week schedule – tap to vote"
        case .days:
            let count = schedule.specificDates?.count ?? 0
            return "LinkUp: \(count) day\(count == 1 ? "" : "s") – tap to vote"
        }
    }
}
