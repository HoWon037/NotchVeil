import Foundation

/// Preference keys and the one-time rename from the bare keys used up to 0.3.1.
/// Kept in the core target so the migration can be tested without AppKit.
public enum NotchVeilDefaultsKey {
    public static let isEnabled = "NotchVeil.isEnabled"
    public static let showsMenuBarIcon = "NotchVeil.showsMenuBarIcon"
    /// cdhash of the app bundle as it was when the login item was registered.
    public static let loginItemAppCodeHash = "NotchVeil.loginItemAppCodeHash"

    static let legacyIsEnabled = "isEnabled"
    static let legacyShowsMenuBarIcon = "showsMenuBarIcon"

    static let renames: [(legacy: String, current: String)] = [
        (legacyIsEnabled, isEnabled),
        (legacyShowsMenuBarIcon, showsMenuBarIcon)
    ]
}

public enum NotchVeilDefaultsMigrator {
    /// Copies a legacy value only when the namespaced key is still unset, so a
    /// newer preference always wins, then drops the legacy key.
    public static func migrate(_ defaults: UserDefaults) {
        for rename in NotchVeilDefaultsKey.renames {
            guard defaults.object(forKey: rename.legacy) != nil else { continue }

            if defaults.object(forKey: rename.current) == nil {
                defaults.set(defaults.bool(forKey: rename.legacy), forKey: rename.current)
            }

            defaults.removeObject(forKey: rename.legacy)
        }
    }
}
