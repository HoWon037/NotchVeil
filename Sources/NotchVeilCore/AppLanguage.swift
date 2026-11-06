import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case korean = "ko"
    case english = "en"
    public var id: String { rawValue }

    public static func restored(_ value: String?) -> Self {
        value.flatMap(Self.init(rawValue:)) ?? .system
    }

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let code = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
                .split(separator: "-").first
            switch code {
            case "ko": return .korean
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    public func text(_ key: AppText) -> String {
        resolved() == .korean ? key.translations.ko : key.translations.en
    }
}

public enum AppText: CaseIterable {
    case settings, notchSection, hideNotch
    case generalSection, launchAtLogin, menuBarIcon, language, systemLanguage
    case quit, openSettings, turnOff, turnOn
    case loginError, approvalTitle, approvalDescription, openSystemSettings, later, ok

    var translations: (ko: String, en: String) {
        switch self {
        case .settings: ("설정", "Settings")
        case .notchSection: ("디스플레이", "Display")
        case .hideNotch: ("노치 가리기", "Hide notch")
        case .generalSection: ("일반", "General")
        case .launchAtLogin: ("로그인할 때 자동 실행", "Launch at login")
        case .menuBarIcon: ("메뉴 막대 아이콘 표시", "Show menu bar icon")
        case .language: ("언어", "Language")
        case .systemLanguage: ("시스템 설정 따름", "Follow system")
        case .quit: ("앱 종료", "Quit App")
        case .openSettings: ("설정 열기…", "Open Settings…")
        case .turnOff: ("노치 가리기 끄기", "Turn Off Notch Hiding")
        case .turnOn: ("노치 가리기 켜기", "Turn On Notch Hiding")
        case .loginError: ("자동 실행을 변경할 수 없습니다", "Couldn’t change launch at login")
        case .approvalTitle: ("로그인 항목 허용이 필요합니다", "Login item approval required")
        case .approvalDescription:
            ("시스템 설정의 로그인 항목에서 NotchVeil을 허용해 주세요.", "Allow NotchVeil in Login Items in System Settings.")
        case .openSystemSettings: ("시스템 설정 열기", "Open System Settings")
        case .later: ("나중에", "Later")
        case .ok: ("확인", "OK")
        }
    }
}
