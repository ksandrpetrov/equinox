import SwiftUI

enum EquinoxAccessibility {
    static func onOffValue(_ isOn: Bool) -> String {
        isOn
            ? String(localized: "On", comment: "Accessibility toggle value")
            : String(localized: "Off", comment: "Accessibility toggle value")
    }
}

extension View {
    func settingsControlLabel(_ title: String, subtitle: String? = nil) -> some View {
        modifier(SettingsControlAccessibilityModifier(title: title, subtitle: subtitle))
    }

    func equinoxAnimation(_ animation: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    func panelAccessibilityLabel(_ label: String, hint: String? = nil) -> some View {
        modifier(PanelAccessibilityModifier(label: label, hint: hint))
    }
}

private struct SettingsControlAccessibilityModifier: ViewModifier {
    let title: String
    let subtitle: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(title)
            .accessibilityHint(subtitle ?? "")
    }
}

private struct PanelAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

struct SettingsLabeledToggle: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityValue(EquinoxAccessibility.onOffValue(isOn))
        }
    }
}
