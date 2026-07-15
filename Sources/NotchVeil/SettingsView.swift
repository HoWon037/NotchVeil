import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let quitAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)

                Text("NotchVeil")
                    .font(.title2.weight(.semibold))

                Spacer()
            }
            .padding(.bottom, 18)

            Divider()

            VStack(spacing: 16) {
                SettingToggleRow(
                    title: "노치 가리기",
                    isOn: Binding(
                        get: { settings.isEnabled },
                        set: { settings.setEnabled($0) }
                    )
                )

                SettingToggleRow(
                    title: "로그인할 때 자동 실행",
                    isOn: Binding(
                        get: { settings.launchesAtLogin },
                        set: { settings.setLaunchesAtLogin($0) }
                    ),
                    isEnabled: settings.canManageLaunchAtLogin
                )

                SettingToggleRow(
                    title: "메뉴 막대 아이콘 표시",
                    isOn: Binding(
                        get: { settings.showsMenuBarIcon },
                        set: { settings.setShowsMenuBarIcon($0) }
                    )
                )
            }
            .padding(.vertical, 18)

            Divider()

            HStack {
                Spacer()
                Button("앱 종료", role: .destructive, action: quitAction)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(!isEnabled)
    }
}
