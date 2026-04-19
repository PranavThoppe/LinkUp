import Foundation

/// Encodes and decodes `MessagePayload` to/from a URL stored on `MSMessage.url`.
///
/// Encoding: MessagePayload → JSON → base64url → URLComponents → URL
/// Decoding: URL → URLComponents → base64url → JSON → MessagePayload
///
/// URLs use the `https://linkup.app` scheme+host so the Messages framework
/// preserves the URL when storing and transmitting bubbles (custom schemes
/// like `linkup://` are silently stripped by the system).
/// The `data` query parameter carries the base64url-encoded JSON blob.
/// All other query items are reserved for future use (e.g. a `sid` shortcut for scheduleId).
enum PayloadCoder {

    private static let queryKey = "data"

    private static var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    private static var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Encode

    static func encode(_ payload: MessagePayload) throws -> URL {
        let data = try encoder.encode(payload)
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "linkup.app"
        components.queryItems = [URLQueryItem(name: queryKey, value: base64)]

        guard let url = components.url else {
            throw CoderError.encodingFailed("Could not build URL from components")
        }
        return url
    }

    // MARK: - Decode

    enum DecodeResult {
        case success(MessagePayload)
        /// The payload version is newer than this client understands. Show "update app" UI.
        case unsupportedVersion(Int)
        /// The URL is not a LinkUp payload.
        case notLinkUp
    }

    static func decode(url: URL) -> DecodeResult {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "linkup.app" else {
            return .notLinkUp
        }

        guard let base64 = components.queryItems?.first(where: { $0.name == queryKey })?.value else {
            return .notLinkUp
        }

        let padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - padded.count % 4) % 4)
        let base64Standard = padded + padding

        guard let data = Data(base64Encoded: base64Standard) else {
            return .notLinkUp
        }

        // Peek at version before full decode to gate unknown-version clients.
        if let versionContainer = try? decoder.decode(VersionContainer.self, from: data),
           versionContainer.version > MessagePayload.currentVersion {
            return .unsupportedVersion(versionContainer.version)
        }

        guard let payload = try? decoder.decode(MessagePayload.self, from: data) else {
            return .notLinkUp
        }

        return .success(payload)
    }

    // MARK: - Errors

    enum CoderError: Error, LocalizedError {
        case encodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .encodingFailed(let msg): return "PayloadCoder encoding failed: \(msg)"
            }
        }
    }

    // MARK: - Private helpers

    private struct VersionContainer: Decodable {
        let version: Int
    }
}
