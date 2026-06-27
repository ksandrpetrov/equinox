import KeyboardShortcuts
import SwiftUI

struct ShortcutsSettingsTab: View {
    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Shortcuts", comment: "Settings section: shortcuts")) {
            SettingsSection(
                String(localized: "Global Shortcut", comment: "Settings shortcuts section"),
                subtitle: String(localized: "Show or hide the Equinox panel from anywhere", comment: "Shortcut section subtitle")
            ) {
                SettingsRow(title: String(localized: "Keyboard shortcut", comment: "")) {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                        .frame(width: 160, height: 28)
                }
            }

            SettingsSection(String(localized: "Panel Shortcuts", comment: "Settings panel shortcuts section")) {
                shortcutRow(String(localized: "New Event", comment: ""), "⌘N")
                SettingsDivider()
                shortcutRow(String(localized: "Pin Equinox", comment: ""), "P")
                SettingsDivider()
                shortcutRow(String(localized: "Preferences…", comment: ""), "⌘,")
                SettingsDivider()
                shortcutRow(String(localized: "Go to Today", comment: "Shortcut cheat sheet"), "T")
            }
        }
    }

    private func shortcutRow(_ title: String, _ shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(EquinoxDesign.monoTimeFont(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, EquinoxDesign.spacingSM)
                .padding(.vertical, EquinoxDesign.spacingXS)
                .background {
                    RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.interactionSubtle)
                        .overlay {
                            RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                                .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
                        }
                }
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }
}
