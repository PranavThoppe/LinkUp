import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    // MARK: - State

    /// The decoded payload from the currently selected message, if any.
    private var activePayload: MessagePayload?

    /// The senderId for the local participant in this conversation.
    private var selfSenderId: String = ""
    private let composerDraft = ComposerDraft()

    // MARK: - Hosted SwiftUI controller

    private var hostedController: UIViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.background)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)

        print("[LinkUp] willBecomeActive — style=\(presentationStyle.rawValue), selectedMessage=\(conversation.selectedMessage != nil ? "SET" : "NIL"), url=\(conversation.selectedMessage?.url?.absoluteString ?? "NIL")")


        selfSenderId = conversation.localParticipantIdentifier.uuidString

        if let selectedMessage = conversation.selectedMessage,
           let url = selectedMessage.url {
            print("[LinkUp] message URL: \(url.absoluteString)")  
            switch PayloadCoder.decode(url: url) {
            case .success(let payload):
                activePayload = payload
            case .unsupportedVersion(let v):
                showUnsupportedVersionUI(version: v)
                return
            case .notLinkUp:
                activePayload = nil
            }
        } else if conversation.selectedMessage != nil {
            // A non-URL message is selected — not a LinkUp bubble.
            activePayload = nil
        }
        // When selectedMessage is nil we preserve whatever activePayload was already set.
        // willBecomeActive fires a second time after requestPresentationStyle(.expanded)
        // completes with selectedMessage == nil; clearing here would wipe the payload
        // before didTransition mounts the voting UI.

        // Auto-expand to the voting view when the user taps an existing schedule bubble.
        if activePayload != nil && presentationStyle == .compact {
            requestPresentationStyle(.expanded)
            return
        }

        presentUI(for: presentationStyle, conversation: conversation)
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
    }

    /// When the user selects a different message in the thread while the extension is open,
    /// refresh decoded state and re-present expanded/compact UI as appropriate.
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)

        print("[LinkUp] didSelect — url: \(message.url?.absoluteString ?? "NIL")")

        selfSenderId = conversation.localParticipantIdentifier.uuidString

        if let url = message.url {
            switch PayloadCoder.decode(url: url) {
            case .success(let payload):
                print("[LinkUp] decode: SUCCESS, mode=\(payload.schedule.mode)")
                activePayload = payload
            case .unsupportedVersion(let v):
                print("[LinkUp] decode: unsupportedVersion \(v)")
                activePayload = nil
                showUnsupportedVersionUI(version: v)
                return
            case .notLinkUp:
                print("[LinkUp] decode: notLinkUp")
                activePayload = nil
            }
        } else {
            print("[LinkUp] didSelect — url is NIL")
            activePayload = nil
        }

        switch presentationStyle {
        case .compact:
            if activePayload != nil {
                requestPresentationStyle(.expanded)
            } else {
                presentCompactView(conversation: conversation)
            }
        case .expanded:
            presentExpandedView(conversation: conversation)
        default:
            break
        }
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
            // MSMessageTemplateLayout is used; the bubble content is the rendered
            // card image set at send time. The extension is never launched in
            // .transcript style with template layouts.
            break
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
            draft: composerDraft,
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

        // Reuse the selected bubble's session only when updating the same schedule
        // (e.g. new votes). A new schedule from the composer has a fresh UUID, so
        // this resolves to a new MSSession and posts a new bubble.
        let message = MSMessage(session: transcriptSession(for: conversation, scheduleId: schedule.id))
        message.url = url
        message.summaryText = summaryText(for: schedule)

        message.layout = TranscriptLayoutBuilder.makeLayout(for: payload, viewerParticipantId: selfSenderId)

        conversation.insert(message) { [weak self] error in
            if error == nil {
                self?.dismiss()
            }
        }
    }

    // MARK: - Expanded (voting or creation)

    private func presentExpandedView(conversation: MSConversation) {
        print("[LinkUp] presentExpandedView — activePayload: \(activePayload != nil ? "SET" : "NULL")") 
        if let payload = activePayload {
            let expandedView = ExpandedView(
                payload: payload,
                selfSenderId: selfSenderId,
                onDone: { [weak self] updatedPayload in
                    self?.submitVote(updatedPayload, conversation: conversation)
                }
            )
            embed(SwiftUI: expandedView)
        } else {
            let composerView = CompactView(
                onSend: { [weak self] schedule in
                    self?.sendSchedule(schedule, conversation: conversation)
                },
                draft: composerDraft,
                isScrollable: true
            )
            embed(SwiftUI: composerView)
        }
    }

    // MARK: - Vote submission

    /// Encodes the updated payload (with new vote merged in) into an MSMessage that
    /// replaces the existing bubble in-place via session reuse.
    private func submitVote(_ updatedPayload: MessagePayload, conversation: MSConversation) {
        guard let url = try? PayloadCoder.encode(updatedPayload) else { return }

        let message = MSMessage(session: transcriptSession(for: conversation, scheduleId: updatedPayload.schedule.id))
        message.url = url
        message.summaryText = summaryText(for: updatedPayload.schedule)
        message.layout = TranscriptLayoutBuilder.makeLayout(for: updatedPayload, viewerParticipantId: selfSenderId)

        conversation.insert(message) { [weak self] error in
            if error == nil {
                self?.dismiss()
            }
        }
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
                .padding(.horizontal, 21)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        embed(SwiftUI: fallback)
    }

    // MARK: - SwiftUI embedding helpers

    private func embed<Content: View>(SwiftUI content: Content) {
        embedHosted(content: content, background: UIColor(Theme.background))
    }

    private func embedHosted<Content: View>(content: Content, background: UIColor) {
        removeHostedController()
        let host = UIHostingController(rootView: content)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = background
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

    /// Session for `MSMessage`: same session updates the transcript bubble in place; a new session adds a new bubble.
    private func transcriptSession(for conversation: MSConversation, scheduleId: UUID) -> MSSession {
        guard let selected = conversation.selectedMessage,
              let url = selected.url,
              case .success(let existing) = PayloadCoder.decode(url: url),
              existing.schedule.id == scheduleId
        else { return MSSession() }
        return selected.session ?? MSSession()
    }

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
