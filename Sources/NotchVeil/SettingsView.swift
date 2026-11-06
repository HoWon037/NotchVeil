import AppKit
import NotchVeilCore
import SwiftUI

struct SettingsView: View {
    private static let settingsIcon: NSImage? = {
        let size = NSSize(width: 44, height: 44)
        let image = NSImage(size: size)
        for suffix in ["", "@2x"] {
            guard let url = Bundle.main.url(forResource: "SettingsIcon\(suffix)", withExtension: "png"),
                let data = try? Data(contentsOf: url),
                let bitmap = NSBitmapImageRep(data: data)
            else { continue }
            bitmap.size = size
            image.addRepresentation(bitmap)
        }
        return image.representations.isEmpty ? nil : image
    }()

    @ObservedObject var settings: AppSettings
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Group {
                    if let icon = Self.settingsIcon {
                        Image(nsImage: icon)
                    } else {
                        Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high)
                    }
                }
                .frame(width: 44, height: 44)

                Text("NotchVeil").font(.title2.weight(.semibold))

                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading(settings.text(.notchSection))
                SettingToggleRow(
                    title: settings.text(.hideNotch),
                    isOn: Binding(
                        get: { settings.isEnabled },
                        set: { settings.setEnabled($0) }
                    )
                )
                .padding(14)
                .background(groupBackground)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionHeading(settings.text(.generalSection))
                VStack(spacing: 0) {
                    SettingToggleRow(
                        title: settings.text(.launchAtLogin),
                        isOn: Binding(
                            get: { settings.launchesAtLogin },
                            set: { settings.setLaunchesAtLogin($0) }
                        ),
                        isEnabled: settings.canManageLaunchAtLogin
                    )
                    .padding(14)
                    Divider().padding(.horizontal, 14)
                    SettingToggleRow(
                        title: settings.text(.menuBarIcon),
                        isOn: Binding(
                            get: { settings.showsMenuBarIcon },
                            set: { settings.setShowsMenuBarIcon($0) }
                        )
                    )
                    .padding(14)
                    Divider().padding(.horizontal, 14)
                    HStack {
                        Text(settings.text(.language))
                        Spacer(minLength: 20)
                        Picker(
                            settings.text(.language),
                            selection: Binding(
                                get: { settings.language },
                                set: { settings.setLanguage($0) }
                            )
                        ) {
                            Text(settings.text(.systemLanguage)).tag(AppLanguage.system)
                            Text("한국어").tag(AppLanguage.korean)
                            Text("English").tag(AppLanguage.english)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .padding(14)
                }
                .background(groupBackground)
            }

            HStack {
                Text(
                    "v"
                        + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                            ?? "—")
                )
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(settings.text(.quit), action: quitAction)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
}

private struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        HStack(alignment: .center) {
            Text(title)

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(!isEnabled)
    }
}
