import SwiftUI

enum SettingsSearchFilter {
    static func matches(searchText: String, keywords: String...) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return keywords
            .flatMap { keyword in
                [keyword, Bundle.equinox.localizedString(forKey: keyword, value: keyword, table: nil)]
            }
            .contains { candidate in
                candidate.localizedCaseInsensitiveContains(query) ||
                    query.localizedCaseInsensitiveContains(candidate)
            }
    }
}

extension View {
    /// macOS NavigationSplitView + unified toolbar can render scroll content under the title bar.
    func settingsToolbarScrollWorkaround() -> some View {
        contentMargins(.top, 1, for: .scrollContent)
    }
}

struct SettingsSidebarLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(EquinoxDesign.ColorToken.textPrimary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(EquinoxDesign.ColorToken.textPrimary)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(EquinoxDesign.sectionHeaderFont())
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, EquinoxDesign.spacingXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { SettingsDivider() }
        }
    }
}

struct SettingsFooter: View {
    let text: String
    var style: Style = .secondary

    enum Style {
        case secondary
        case error
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(style == .error ? EquinoxDesign.ColorToken.semanticRed : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsDesign.sectionSpacing) {
                content()
            }
            .padding(SettingsDesign.detailPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .settingsToolbarScrollWorkaround()
        .scrollIndicators(.hidden)
        .navigationTitle(title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: EquinoxDesign.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .settingsControlLabel(title, subtitle: subtitle)
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(EquinoxDesign.ColorToken.separator)
            .frame(height: EquinoxDesign.hairlineWidth)
    }
}

struct SettingsSegmentedPicker: View {
    let label: String
    let options: [String]
    @Binding var selection: Int

    init(label: String = "", options: [String], selection: Binding<Int>) {
        self.label = label
        self.options = options
        self._selection = selection
    }

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(options.indices, id: \.self) { i in
                Text(options[i]).tag(i)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(label.isEmpty ? String(localized: "Options", bundle: .equinox, comment: "Segmented picker") : label)
        .accessibilityValue(options.indices.contains(selection) ? options[selection] : "")
    }
}
