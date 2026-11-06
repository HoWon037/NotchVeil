import Testing

@testable import NotchVeilCore

@Test func systemLanguageUsesKoreanOrFallsBackToEnglish() {
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ko-KR", "en"]) == .korean)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["en-US"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "ko-KR", "en"]) == .korean)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["en-US", "ko-KR"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["KO_kr"]) == .korean)
    #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
}

@Test func explicitLanguageOverridesSystemPreference() {
    #expect(AppLanguage.english.resolved(preferredLanguages: ["ko-KR"]) == .english)
    #expect(AppLanguage.korean.resolved(preferredLanguages: ["en-US"]) == .korean)
}

@Test func savedLanguageRestoresAndUnknownValuesFollowSystem() {
    for language in AppLanguage.allCases {
        #expect(AppLanguage.restored(language.rawValue) == language)
    }
    #expect(AppLanguage.restored(nil) == .system)
    #expect(AppLanguage.restored("unsupported") == .system)
}

@Test func allVisibleCopyHasBothTranslations() {
    for key in AppText.allCases {
        #expect(!AppLanguage.english.text(key).isEmpty)
        #expect(!AppLanguage.korean.text(key).isEmpty)
        #expect(AppLanguage.english.text(key) != AppLanguage.korean.text(key))
    }
}
