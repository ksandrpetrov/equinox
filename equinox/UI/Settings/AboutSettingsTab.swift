import SwiftUI

struct AboutSettingsTab: View {
    var searchText: String = ""

    var body: some View {
        Group {
            if SettingsSearchFilter.matches(
                searchText: searchText,
                keywords: "About", "Equinox", "Version", "MIT License", "View on GitHub"
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

            Spacer()
        }
        .padding(EquinoxDesign.spacingXL + EquinoxDesign.spacingMD)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
