import Foundation
import Testing
@testable import NotchVeilCore

private func makeDefaults() throws -> UserDefaults {
    let suiteName = "NotchVeilTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@Test func movesLegacyValuesToNamespacedKeys() throws {
    let defaults = try makeDefaults()
    defaults.set(false, forKey: NotchVeilDefaultsKey.legacyIsEnabled)
    defaults.set(true, forKey: NotchVeilDefaultsKey.legacyShowsMenuBarIcon)

    NotchVeilDefaultsMigrator.migrate(defaults)

    #expect(defaults.bool(forKey: NotchVeilDefaultsKey.isEnabled) == false)
    #expect(defaults.bool(forKey: NotchVeilDefaultsKey.showsMenuBarIcon) == true)
    #expect(defaults.object(forKey: NotchVeilDefaultsKey.legacyIsEnabled) == nil)
    #expect(defaults.object(forKey: NotchVeilDefaultsKey.legacyShowsMenuBarIcon) == nil)
}

@Test func keepsAnExistingNamespacedValue() throws {
    let defaults = try makeDefaults()
    defaults.set(true, forKey: NotchVeilDefaultsKey.legacyIsEnabled)
    defaults.set(false, forKey: NotchVeilDefaultsKey.isEnabled)

    NotchVeilDefaultsMigrator.migrate(defaults)

    #expect(defaults.bool(forKey: NotchVeilDefaultsKey.isEnabled) == false)
    #expect(defaults.object(forKey: NotchVeilDefaultsKey.legacyIsEnabled) == nil)
}

@Test func leavesUntouchedDefaultsAlone() throws {
    let defaults = try makeDefaults()

    NotchVeilDefaultsMigrator.migrate(defaults)

    #expect(defaults.object(forKey: NotchVeilDefaultsKey.isEnabled) == nil)
    #expect(defaults.object(forKey: NotchVeilDefaultsKey.showsMenuBarIcon) == nil)
}
