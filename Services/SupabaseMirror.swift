import Foundation
import os

/// Votes + participants fetched from the Supabase mirror for a single schedule.
struct MergedScheduleState {
    let votes: [Vote]
    let participants: [Participant]
}

/// Fire-and-forget mirror of `MessagePayload` to Supabase via PostgREST `submit_payload`,
/// plus a background read that merges all participants' votes from the DB.
final class SupabaseMirror {

    static let shared = SupabaseMirror()

    private let session: URLSession
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LinkUp", category: "SupabaseMirror")

    private static var jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    private static var dbDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private struct SubmitPayloadRPC: Encodable {
        let payload: MessagePayload
    }

    // MARK: - DB row types (PostgREST response, snake_case → camelCase via decoder)

    private struct DBVoteRow: Decodable {
        let voteId: String
        let participantImessageUuid: String
        let senderInitial: String
        let senderColor: String
        let dates: [String]
        let slots: [SlotSelection]?
        let hours: [HourSelection]?
        let updatedAt: String
        let voteRevision: Int

        func toVote() -> Vote? {
            guard let uuid = UUID(uuidString: voteId) else { return nil }
            let date = Self.parseDate(updatedAt) ?? Date()
            return Vote(
                id: uuid,
                senderId: participantImessageUuid,
                senderInitial: senderInitial,
                senderColor: senderColor,
                dates: dates,
                slots: slots,
                hours: hours,
                updatedAt: date,
                voteRevision: voteRevision
            )
        }

        private static func parseDate(_ s: String) -> Date? {
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withFractional.date(from: s) { return d }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return plain.date(from: s)
        }
    }

    private struct DBParticipantRow: Decodable {
        let imessageUuid: String
        let initial: String
        let color: String
        let name: String?

        func toParticipant() -> Participant {
            Participant(id: imessageUuid, initial: initial, color: color, name: name)
        }
    }

    private enum FetchError: Error {
        case notConfigured
        case httpError(Int, String)
    }

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func mirror(_ payload: MessagePayload) async {
        guard let base = Self.rpcURL() else {
            log.debug("Supabase mirror skipped: invalid or missing SUPABASE_URL")
            return
        }
        guard let key = SupabaseConfig.anonKey else {
            log.debug("Supabase mirror skipped: invalid or missing SUPABASE_ANON_KEY")
            return
        }

        let bodyData: Data
        do {
            bodyData = try Self.jsonEncoder.encode(SubmitPayloadRPC(payload: payload))
        } catch {
            log.error("Supabase mirror encode failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        #if DEBUG
        print("[SupabaseMirror DEBUG] POST \(base.absoluteString) httpBodyBytes=\(bodyData.count)")
        #endif

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                log.error("Supabase mirror: non-HTTP response")
                return
            }
            let bodyDescription = Self.responseBodyDescription(data)
            #if DEBUG
            print("[SupabaseMirror DEBUG] status=\(http.statusCode) body=\(bodyDescription)")
            #endif
            guard (200..<300).contains(http.statusCode) else {
                log.error("Supabase mirror HTTP \(http.statusCode, privacy: .public) body: \(bodyDescription, privacy: .public)")
                return
            }
        } catch {
            log.error("Supabase mirror request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Background fetch (merged votes from DB)

    /// Fetches all votes and participants for `scheduleId` from the Supabase mirror.
    /// Each participant's row is independent so this returns the true merged state
    /// even when two people voted concurrently from the same bubble snapshot.
    func fetchMergedState(scheduleId: UUID) async throws -> MergedScheduleState {
        guard let projectURL = SupabaseConfig.projectURL,
              let key = SupabaseConfig.anonKey else {
            throw FetchError.notConfigured
        }

        let idParam = "eq.\(scheduleId.uuidString)"
        guard let votesURL = Self.restTableURL(base: projectURL, table: "votes",
                                               params: [("schedule_id", idParam), ("select", "*")]),
              let participantsURL = Self.restTableURL(base: projectURL, table: "participants",
                                                      params: [("schedule_id", idParam), ("select", "*")]) else {
            throw FetchError.notConfigured
        }

        async let dbVoteRows    = get(url: votesURL, key: key, as: [DBVoteRow].self)
        async let dbParticipantRows = get(url: participantsURL, key: key, as: [DBParticipantRow].self)

        let votes        = try await dbVoteRows.compactMap { $0.toVote() }
        let participants = try await dbParticipantRows.map { $0.toParticipant() }

        return MergedScheduleState(votes: votes, participants: participants)
    }

    private func get<T: Decodable>(url: URL, key: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.httpError(0, "non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            log.error("Supabase fetch HTTP \(http.statusCode, privacy: .public): \(body, privacy: .public)")
            throw FetchError.httpError(http.statusCode, body)
        }
        return try Self.dbDecoder.decode(T.self, from: data)
    }

    // MARK: - URL helpers

    private static func rpcURL() -> URL? {
        guard let projectURL = SupabaseConfig.projectURL,
              var components = URLComponents(url: projectURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var path = components.path
        if path.hasSuffix("/") { path.removeLast() }
        components.path = path + "/rest/v1/rpc/submit_payload"
        return components.url
    }

    private static func restTableURL(base: URL, table: String,
                                     params: [(String, String)]) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var path = components.path
        if path.hasSuffix("/") { path.removeLast() }
        components.path = path + "/rest/v1/\(table)"
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url
    }

    private static func responseBodyDescription(_ data: Data) -> String {
        if data.isEmpty { return "<empty>" }
        if let s = String(data: data, encoding: .utf8) { return s }
        return "<non-utf8, \(data.count) bytes>"
    }
}
