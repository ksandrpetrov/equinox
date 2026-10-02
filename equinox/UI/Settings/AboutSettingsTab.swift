import SwiftUI

struct AboutSettingsTab: View {
    var searchText: String = ""
    @State private var showsLicenses = false

    var body: some View {
        Group {
            if SettingsSearchFilter.matches(
                searchText: searchText,
                keywords: "About", "Equinox", "Version", "MIT License", "View on GitHub", "Support", "Privacy Policy", "Licenses"
            ) {
                aboutContent
            } else {
                ContentUnavailableView(
                    String(localized: "No Results", bundle: .equinox, comment: "Settings search empty"),
                    systemImage: "magnifyingglass",
                    description: Text(String(localized: "Try a different search term.", bundle: .equinox, comment: ""))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "About", bundle: .equinox, comment: "About prefs tab label"))
        .sheet(isPresented: $showsLicenses) { licensesContent }
    }

    private var licensesContent: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingMD) {
            Text(String(localized: "Licenses", bundle: .equinox, comment: "License viewer title"))
                .font(.headline)
            ScrollView {
                Text(licenseText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(String(localized: "Done", bundle: .equinox, comment: "Close license viewer")) {
                showsLicenses = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(EquinoxDesign.spacingLG)
        .frame(width: SettingsDesign.windowMinWidth - SettingsDesign.sidebarWidth,
               height: SettingsDesign.windowMinHeight)
    }

    private var licenseText: String {
        guard let url = Bundle.equinox.url(forResource: "Licenses", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return String(localized: "Licenses could not be loaded.", bundle: .equinox, comment: "License resource error")
        }
        return text
    }

    private var aboutContent: some View {
        VStack(spacing: EquinoxDesign.spacingLG) {
            Spacer()

            Image("AppLogo", bundle: .equinox)
                .resizable()
                .interpolation(.high)
                .frame(width: EquinoxDesign.ControlWidth.aboutLogo, height: EquinoxDesign.ControlWidth.aboutLogo)

            Text(String(localized: "Equinox", bundle: .equinox, comment: "App name"))
                .font(EquinoxDesign.aboutTitleFont())

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("\(String(localized: "Version", bundle: .equinox, comment: "")) \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "MIT License", bundle: .equinox, comment: "About license line"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Link(
                String(localized: "View on GitHub", bundle: .equinox, comment: "About link"),
                destination: URL(string: "https://github.com/ksandrpetrov/equinox")!
            )
            .font(.footnote)
            .foregroundStyle(EquinoxDesign.ColorToken.semanticBlue)

            HStack(spacing: EquinoxDesign.spacingMD) {
                Link(String(localized: "Privacy Policy", bundle: .equinox, comment: "Privacy policy link"),
                     destination: EquinoxDocumentation.privacyPolicy)
                Link(String(localized: "Support", bundle: .equinox, comment: "Support link"),
                     destination: EquinoxDocumentation.support)
                Button(String(localized: "Licenses", bundle: .equinox, comment: "Open license viewer")) {
                    showsLicenses = true
                }
                .buttonStyle(.link)
            }
            .font(.footnote)

            Spacer()
        }
        .padding(EquinoxDesign.spacingXL + EquinoxDesign.spacingMD)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
