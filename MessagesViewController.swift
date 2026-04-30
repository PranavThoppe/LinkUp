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
    private var monthVoteDraft: MonthVoteDraft?
    private var monthVoteDraftScheduleId: UUID?
    private var monthVoteDraftPayloadRevision: Int?
    private var weekVoteDraft: WeekVoteDraft?
    private var weekVoteDraftScheduleId: UUID?
    private var daysVoteDraft: DaysVoteDraft?
    private var daysVoteDraftScheduleId: UUID?

    // MARK: - Hosted SwiftUI controller

    private var hostedController: UIViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.background)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        UserProfileLocalState.applyV1ProfileRolloutStrippingLegacyIfNeeded()
        print("🔑 storedUsername = \(String(describing: storedUsername))")

        guard storedUsername != nil else {
            presentUsernameSetup()
            return
        }

        selfSenderId = conversation.localParticipantIdentifier.uuidString

        #if DEBUG
        SupabaseMirrorDebugSmoke.runOnceIfNeeded(selfSenderId: selfSenderId)
        #endif

        if let selectedMessage = conversation.selectedMessage,
           let url = selectedMessage.url {
            switch PayloadCoder.decode(url: url) {
            case .success(let payload):
                activePayload = payload
                resetMonthVoteDraftIfNeeded(for: payload)
                hydrateMergedVotes(scheduleId: payload.schedule.id)
            case .unsupportedVersion(let v):
                showUnsupportedVersionUI(version: v)
                return
            case .notLinkUp:
                activePayload = nil
                monthVoteDraft = nil
                monthVoteDraftScheduleId = nil
                monthVoteDraftPayloadRevision = nil
            }
        } else if conversation.selectedMessage != nil {
            // A non-URL message is selected — not a LinkUp bubble.
            activePayload = nil
            monthVoteDraft = nil
            monthVoteDraftScheduleId = nil
            monthVoteDraftPayloadRevision = nil
        }
        // When selectedMessage is nil we preserve whatever activePayload was already set.
        // willBecomeActive fires a second time after requestPresentationStyle(.expanded)
        // completes with selectedMessage == nil; clearing here would wipe the payload
        // before didTransition mounts the voting UI.

        // Auto-expand to the voting view when the user taps an existing schedule bubble.
        if activePayload != nil && presentationStyle == .compact && conversation.selectedMessage != nil {
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

        selfSenderId = conversation.localParticipantIdentifier.uuidString

        if let url = message.url {
            switch PayloadCoder.decode(url: url) {
            case .success(let payload):
                activePayload = payload
                resetMonthVoteDraftIfNeeded(for: payload)
                hydrateMergedVotes(scheduleId: payload.schedule.id)
            case .unsupportedVersion(let v):
                activePayload = nil
                monthVoteDraft = nil
                monthVoteDraftScheduleId = nil
                monthVoteDraftPayloadRevision = nil
                showUnsupportedVersionUI(version: v)
                return
            case .notLinkUp:
                activePayload = nil
                monthVoteDraft = nil
                monthVoteDraftScheduleId = nil
                monthVoteDraftPayloadRevision = nil
            }
        } else {
            activePayload = nil
            monthVoteDraft = nil
            monthVoteDraftScheduleId = nil
            monthVoteDraftPayloadRevision = nil
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
        guard storedUsername != nil else {
            presentUsernameSetup()
            return
        }
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
        if let payload = activePayload, payload.schedule.mode == .month {
            let compactSlotsView = MonthSlotsCompactView(
                payload: payload,
                selfSenderId: selfSenderId,
                voteDraft: monthVoteDraft(for: payload),
                onSave: { [weak self] updatedPayload in
                    self?.submitVote(updatedPayload, conversation: conversation)
                },
                onExpand: { [weak self] in
                    self?.requestPresentationStyle(.expanded)
                }
            )
            embed(SwiftUI: compactSlotsView)
            return
        }

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
            eligibleDateRange: partialSchedule.eligibleDateRange,
            eligibleSpecificDates: partialSchedule.eligibleSpecificDates,
            createdAt: partialSchedule.createdAt,
            updatedAt: Date(),
            isActive: partialSchedule.isActive
        )

        let cachedName = UserProfileLocalState.cachedDisplayName
        let nameForInitial = cachedName ?? selfSenderId
        let selfInitial = String(nameForInitial.prefix(1)).uppercased()
        let selfColor = UserProfileLocalState.cachedColorHex ?? Participant.color(for: 0)

        let selfParticipant = Participant(
            id: selfSenderId,
            initial: selfInitial,
            color: selfColor,
            name: cachedName
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

        Task.detached { await SupabaseMirror.shared.mirror(payload) }

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

    private func presentExpandedView(conversation: MSConversation, showNewVotesToast: Bool = false) {
        if let payload = activePayload {
            let expandedView = ExpandedView(
                payload: payload,
                selfSenderId: selfSenderId,
                monthVoteDraft: payload.schedule.mode == .month ? monthVoteDraft(for: payload) : nil,
                weekVoteDraft: payload.schedule.mode == .week ? weekVoteDraft(for: payload) : nil,
                daysVoteDraft: payload.schedule.mode == .days ? daysVoteDraft(for: payload) : nil,
                showNewVotesToast: showNewVotesToast,
                onDone: { [weak self] updatedPayload in
                    self?.submitVote(updatedPayload, conversation: conversation)
                },
                onCollapseToCompact: { [weak self] in
                    self?.requestPresentationStyle(.compact)
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

        Task.detached { await SupabaseMirror.shared.mirror(updatedPayload) }

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

    // MARK: - Username

    private var storedUsername: String? {
        UserProfileLocalState.cachedDisplayName ?? UserDefaults.standard.string(forKey: "linkup_username")
    }

    private func presentUsernameSetup() {
        let prefill = UserProfileLocalState.legacyUsernamePrefill
        let draftColor = UserProfileLocalState.onboardingDraftColorHex
        let setupView = UsernameSetupView(initialName: prefill, lockedColorHex: draftColor) { [weak self] name, colorHex in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            // Keep legacy key temporarily while other call sites still read it.
            UserDefaults.standard.set(trimmed, forKey: "linkup_username")
            UserProfileLocalState.cachedDisplayName = trimmed
            UserProfileLocalState.cachedColorHex = colorHex
            UserProfileLocalState.onboardingDraftColorHex = nil
            UserProfileLocalState.clearLegacyUsernamePrefill()
            let profileId = UserProfileLocalState.linkupProfileId

            let iMessageUUID = self?.activeConversation?.localParticipantIdentifier.uuidString
            Task.detached {
                await SupabaseMirror.shared.upsertUserProfile(
                    profileId: profileId,
                    displayName: trimmed,
                    colorHex: colorHex,
                    iMessageUUID: iMessageUUID
                )
            }

            UserProfileLocalState.isProfileOnboardingV1Complete = true

            guard let self, let conv = self.activeConversation else { return }
            self.selfSenderId = conv.localParticipantIdentifier.uuidString
            self.presentUI(for: self.presentationStyle, conversation: conv)
        }
        embed(SwiftUI: setupView)
    }

    // MARK: - Background DB hydration

    /// Fires a background fetch for the schedule's merged votes from Supabase.
    /// When the response arrives, merges any votes/participants not already in
    /// `activePayload` (using per-sender `voteRevision` as the conflict resolver)
    /// then re-presents the expanded view so the user sees everyone's selections.
    /// If the local user has unsaved edits their draft is preserved and a toast is shown.
    private func hydrateMergedVotes(scheduleId: UUID) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let merged = try await SupabaseMirror.shared.fetchMergedState(scheduleId: scheduleId)
                await MainActor.run { [weak self] in
                    guard let self,
                          let current = activePayload,
                          current.schedule.id == scheduleId,
                          let conversation = activeConversation else { return }

                    var mergedVotes = current.votes
                    for dbVote in merged.votes {
                        if let idx = mergedVotes.firstIndex(where: { $0.senderId == dbVote.senderId }) {
                            if dbVote.voteRevision >= mergedVotes[idx].voteRevision {
                                mergedVotes[idx] = dbVote
                            }
                        } else {
                            mergedVotes.append(dbVote)
                        }
                    }

                    var mergedParticipants = current.participants
                    for dbParticipant in merged.participants {
                        if !mergedParticipants.contains(where: { $0.id == dbParticipant.id }) {
                            mergedParticipants.append(dbParticipant)
                        }
                    }

                    let updatedPayload = MessagePayload(
                        version: current.version,
                        schedule: current.schedule,
                        votes: mergedVotes,
                        participants: mergedParticipants,
                        revision: current.revision,
                        lastWriterId: current.lastWriterId
                    )

                    // Check whether the local user has in-progress edits that haven't been sent.
                    // If so, preserve the draft and show a toast instead of wiping their picks.
                    let hasUnsavedEdits: Bool = {
                        switch updatedPayload.schedule.mode {
                        case .month:
                            guard let draft = self.monthVoteDraft else { return false }
                            return hasMonthVoteChanges(
                                payload: updatedPayload,
                                selfSenderId: self.selfSenderId,
                                selectedDates: draft.selectedDates,
                                selectedSlotKeys: draft.selectedSlotKeys
                            )
                        case .week:
                            guard let draft = self.weekVoteDraft else { return false }
                            return hasSlotVoteChanges(
                                payload: updatedPayload,
                                selfSenderId: self.selfSenderId,
                                wholeDayDates: draft.selectedDates,
                                selectedSlotKeys: draft.selectedSlotKeys,
                                selectedHourKeys: draft.selectedHourKeys
                            )
                        case .days:
                            guard let draft = self.daysVoteDraft else { return false }
                            return hasSlotVoteChanges(
                                payload: updatedPayload,
                                selfSenderId: self.selfSenderId,
                                wholeDayDates: draft.selectedDates,
                                selectedSlotKeys: draft.selectedSlotKeys,
                                selectedHourKeys: draft.selectedHourKeys
                            )
                        }
                    }()

                    activePayload = updatedPayload

                    if hasUnsavedEdits {
                        // Keep the existing draft objects intact — the user is mid-edit.
                        // Re-present so other participants' updated votes are visible,
                        // passing the same draft references (they survive as ObservableObjects).
                        if presentationStyle == .expanded {
                            presentExpandedView(conversation: conversation, showNewVotesToast: true)
                        }
                    } else {
                        monthVoteDraft = nil; monthVoteDraftScheduleId = nil; monthVoteDraftPayloadRevision = nil
                        weekVoteDraft  = nil; weekVoteDraftScheduleId  = nil
                        daysVoteDraft  = nil; daysVoteDraftScheduleId  = nil

                        if presentationStyle == .expanded {
                            presentExpandedView(conversation: conversation)
                        }
                    }
                }
            } catch {
                // Non-fatal: bubble state is still valid without the DB merge.
            }
        }
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

    private func monthVoteDraft(for payload: MessagePayload) -> MonthVoteDraft {
        if payload.schedule.mode != .month {
            return MonthVoteDraft(payload: payload, selfSenderId: selfSenderId)
        }
        if let existing = monthVoteDraft,
           monthVoteDraftScheduleId == payload.schedule.id,
           monthVoteDraftPayloadRevision == payload.revision {
            return existing
        }
        let draft = MonthVoteDraft(payload: payload, selfSenderId: selfSenderId)
        monthVoteDraft = draft
        monthVoteDraftScheduleId = payload.schedule.id
        monthVoteDraftPayloadRevision = payload.revision
        return draft
    }

    private func weekVoteDraft(for payload: MessagePayload) -> WeekVoteDraft {
        if let existing = weekVoteDraft, weekVoteDraftScheduleId == payload.schedule.id {
            return existing
        }
        let draft = WeekVoteDraft(payload: payload, selfSenderId: selfSenderId)
        weekVoteDraft = draft
        weekVoteDraftScheduleId = payload.schedule.id
        return draft
    }

    private func daysVoteDraft(for payload: MessagePayload) -> DaysVoteDraft {
        if let existing = daysVoteDraft, daysVoteDraftScheduleId == payload.schedule.id {
            return existing
        }
        let draft = DaysVoteDraft(payload: payload, selfSenderId: selfSenderId)
        daysVoteDraft = draft
        daysVoteDraftScheduleId = payload.schedule.id
        return draft
    }

    private func resetMonthVoteDraftIfNeeded(for payload: MessagePayload) {
        switch payload.schedule.mode {
        case .month:
            if monthVoteDraftScheduleId != payload.schedule.id {
                // Different schedule entirely — always reset.
                monthVoteDraft = MonthVoteDraft(payload: payload, selfSenderId: selfSenderId)
                monthVoteDraftScheduleId = payload.schedule.id
                monthVoteDraftPayloadRevision = payload.revision
            } else if monthVoteDraftPayloadRevision != payload.revision {
                // Same schedule, bubble revision bumped (another user sent).
                // Only reset if the local user has no unsaved edits.
                let hasUnsaved = monthVoteDraft.map { draft in
                    hasMonthVoteChanges(
                        payload: payload,
                        selfSenderId: selfSenderId,
                        selectedDates: draft.selectedDates,
                        selectedSlotKeys: draft.selectedSlotKeys
                    )
                } ?? false

                if !hasUnsaved {
                    monthVoteDraft = MonthVoteDraft(payload: payload, selfSenderId: selfSenderId)
                }
                // Always update the tracked revision so this branch doesn't re-fire on
                // every subsequent willBecomeActive for the same bubble.
                monthVoteDraftPayloadRevision = payload.revision
            }
            weekVoteDraft = nil
            weekVoteDraftScheduleId = nil
            daysVoteDraft = nil
            daysVoteDraftScheduleId = nil
        case .week:
            monthVoteDraft = nil
            monthVoteDraftScheduleId = nil
            monthVoteDraftPayloadRevision = nil
            if weekVoteDraftScheduleId != payload.schedule.id {
                weekVoteDraft = WeekVoteDraft(payload: payload, selfSenderId: selfSenderId)
                weekVoteDraftScheduleId = payload.schedule.id
            }
            daysVoteDraft = nil
            daysVoteDraftScheduleId = nil
        case .days:
            monthVoteDraft = nil
            monthVoteDraftScheduleId = nil
            monthVoteDraftPayloadRevision = nil
            weekVoteDraft = nil
            weekVoteDraftScheduleId = nil
            if daysVoteDraftScheduleId != payload.schedule.id {
                daysVoteDraft = DaysVoteDraft(payload: payload, selfSenderId: selfSenderId)
                daysVoteDraftScheduleId = payload.schedule.id
            }
        }
    }
}

#if DEBUG
/// One-shot RPC smoke test (Debug builds only). Fixed schedule UUID for SQL checks:
/// `select * from schedules where id = '550e8400-e29b-41d4-a716-446655440000';`
private enum SupabaseMirrorDebugSmoke {
    private static let fixedScheduleId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
    private static var didRun = false

    static func runOnceIfNeeded(selfSenderId: String) {
        guard !didRun else { return }
        didRun = true

        let now = Date()
        let schedule = Schedule(
            id: fixedScheduleId,
            creatorId: selfSenderId,
            mode: .week,
            title: "Debug mirror smoke test",
            months: nil,
            weekRange: DateRange(startIso: "2026-04-21", endIso: "2026-04-27"),
            specificDates: nil,
            eligibleDateRange: nil,
            eligibleSpecificDates: nil,
            createdAt: now,
            updatedAt: now,
            isActive: true
        )

        let namePrefix = String(selfSenderId.prefix(1)).uppercased()
        let selfParticipant = Participant(
            id: selfSenderId,
            initial: namePrefix,
            color: Participant.color(for: 0),
            name: nil
        )

        let payload = MessagePayload(
            version: MessagePayload.currentVersion,
            schedule: schedule,
            votes: [],
            participants: [selfParticipant],
            revision: 0,
            lastWriterId: selfSenderId
        )

        print("[SupabaseMirror DEBUG] smoke test: two identical mirror() calls (idempotency). schedule_id=\(fixedScheduleId.uuidString)")
        Task {
            await SupabaseMirror.shared.mirror(payload)
            await SupabaseMirror.shared.mirror(payload)
            print("[SupabaseMirror DEBUG] smoke test mirror calls finished.")
        }
    }
}
#endif
