import Foundation

/// Reads Supabase connection values from `Info.plist` (typically supplied via `Config/Supabase.xcconfig`).
enum SupabaseConfig {

    private static func string(forKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Unsubstituted build-setting placeholders, e.g. $(SUPABASE_URL)
        if trimmed.hasPrefix("$("), trimmed.hasSuffix(")") { return nil }
        return trimmed
    }

    /// Project URL from `SUPABASE_URL` (no trailing slash required).
    static var projectURL: URL? {
        guard let s = string(forKey: "SUPABASE_URL") else { return nil }
        return URL(string: s)
    }

    static var anonKey: String? {
        string(forKey: "SUPABASE_ANON_KEY")
    }
}
