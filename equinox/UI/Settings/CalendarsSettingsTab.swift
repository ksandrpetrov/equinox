import SwiftUI

struct CalendarsSettingsTab: View {
    var searchText: String = ""
    @State private var filterText = ""

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Calendars", comment: "")) {
            SettingsSection(
                String(localized: "Visible Calendars", comment: "Settings calendars section title"),
                subtitle: String(localized: "Choose which calendars appear in Equinox", comment: "Calendars section subtitle")
            ) {
                CalendarsSettingsSection(filterText: effectiveFilter)
            }
        }
    }

    private var effectiveFilter: String {
        if !searchText.isEmpty { return searchText }
        return filterText
    }
}
