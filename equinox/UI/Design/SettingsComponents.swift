import SwiftUI

enum SettingsSearchFilter {
    static func matches(searchText: String, keywords: String...) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return keywords.contains { $0.lowercased().contains(query) || query.contains($0.lowercased()) }
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
        Label(title, systemImage: symbol)
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
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingXS)
            .background {
                RoundedRectangle(cornerRadius: SettingsDesign.sectionCornerRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
            }
        }
    }
}

struct SettingsFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
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
        Divider()
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
        .accessibilityLabel(label.isEmpty ? String(localized: "Options", comment: "Segmented picker") : label)
        .accessibilityValue(selection < options.count ? options[selection] : "")
    }
}
