import Foundation

/// Local state for the global user profile: `linkup_profile_id` in UserDefaults, display/color cache, and v1 rollout.
enum UserProfileLocalState {

    private enum Keys {
        static let profileId = "linkup_profile_id_uuid"
        static let displayName = "linkup_profile_display_name"
        static let colorHex = "linkup_profile_color_hex"
        static let onboardingV1Done = "linkup_profile_onboarding_v1_done"
        /// One-shot prefill for v1 onboarding after legacy `linkup_username` is stripped.
        static let legacyUsernamePrefill = "linkup_profile_v1_legacy_username_prefill"
        /// Color locked during onboarding before Continue; survives expand/compact recreation of the SwiftUI view.
        static let onboardingDraftColorHex = "linkup_profile_onboarding_draft_color_hex"
    }

    private static let usernameLegacy = "linkup_username"

    // MARK: - Profile id (UserDefaults)

    /// Stable `linkup_profile_id` for cross-schedule identity; created on first read.
    static var linkupProfileId: UUID {
        if let s = UserDefaults.standard.string(forKey: Keys.profileId), let u = UUID(uuidString: s) {
            return u
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: Keys.profileId)
        return id
    }

    // MARK: - UserDefaults cache (server row mirror for UI / payloads)

    static var cachedDisplayName: String? {
        get { UserDefaults.standard.string(forKey: Keys.displayName) }
        set {
            if let v = newValue, !v.isEmpty {
                UserDefaults.standard.set(v, forKey: Keys.displayName)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.displayName)
            }
        }
    }

    static var cachedColorHex: String? {
        get { UserDefaults.standard.string(forKey: Keys.colorHex) }
        set {
            if let v = newValue, !v.isEmpty {
                UserDefaults.standard.set(v, forKey: Keys.colorHex)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.colorHex)
            }
        }
    }

    // MARK: - V1 controlled rollout

    static var isProfileOnboardingV1Complete: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.onboardingV1Done) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.onboardingV1Done) }
    }

    /// Text field prefill from legacy username (set during rollout before legacy key is removed). Empty if none.
    static var legacyUsernamePrefill: String {
        UserDefaults.standard.string(forKey: Keys.legacyUsernamePrefill) ?? ""
    }

    static func clearLegacyUsernamePrefill() {
        UserDefaults.standard.removeObject(forKey: Keys.legacyUsernamePrefill)
    }

    /// Non-nil while the user has tapped “Assign my color” but not finished onboarding (Continue).
    static var onboardingDraftColorHex: String? {
        get {
            let s = UserDefaults.standard.string(forKey: Keys.onboardingDraftColorHex)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (s?.isEmpty == false) ? s : nil
        }
        set {
            if let v = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                UserDefaults.standard.set(v, forKey: Keys.onboardingDraftColorHex)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.onboardingDraftColorHex)
            }
        }
    }

    /// Until the user finishes v1 profile onboarding, strip legacy `linkup_username` so the app treats them as not onboarded on the new flow. Safe to call every activation.
    /// If legacy username exists and there is no v1 cached display name, copies it to `legacyUsernamePrefill` first so onboarding can pre-fill the field.
    static func applyV1ProfileRolloutStrippingLegacyIfNeeded() {
        guard !isProfileOnboardingV1Complete else { return }

        if cachedDisplayName == nil,
           let legacy = UserDefaults.standard.string(forKey: usernameLegacy)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !legacy.isEmpty
        {
            let prefillNow = UserDefaults.standard.string(forKey: Keys.legacyUsernamePrefill)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if prefillNow.isEmpty {
                UserDefaults.standard.set(legacy, forKey: Keys.legacyUsernamePrefill)
            }
        }

        UserDefaults.standard.removeObject(forKey: usernameLegacy)
    }
}
