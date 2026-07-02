import SwiftUI

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: EquinoxDesign.spacingLG) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: EquinoxDesign.ControlWidth.aboutLogo, height: EquinoxDesign.ControlWidth.aboutLogo)

            Text(String(localized: "Equinox", comment: "App name"))
                .font(EquinoxDesign.aboutTitleFont())

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("\(String(localized: "Version", comment: "")) \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "MIT License", comment: "About license line"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Link(
                String(localized: "View on GitHub", comment: "About link"),
                destination: URL(string: "https://github.com/aleksandr/equinox")!
            )
            .font(.footnote)
            .foregroundStyle(EquinoxDesign.ColorToken.semanticBlue)

            Spacer()
        }
        .padding(EquinoxDesign.spacingXL + EquinoxDesign.spacingMD)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "About", comment: "About prefs tab label"))
    }
}
