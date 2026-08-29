import SwiftUI

struct PanelCommandBar: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics

    private var monthTitle: String {
        EquinoxFormatters.formatter(key: "month.year") { $0.dateFormat = "MMMM yyyy" }
            .string(from: appState.events.monthDate.date(in: appState.calendar))
    }

    var body: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            PanelButtonGroup(spacing: EquinoxDesign.spacingMicro, showsBackground: true) {
                PanelIconButton(
                    symbol: "chevron.left",
                    help: String(localized: "Previous month", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    appState.goToPreviousMonth()
                }
                .disabled(!appState.events.canGoToPreviousMonth)
                PanelIconButton(
                    symbol: "chevron.right",
                    help: String(localized: "Next month", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    appState.goToNextMonth()
                }
                .disabled(!appState.events.canGoToNextMonth)
            }

            Text(monthTitle)
                .font(EquinoxDesign.calendarTitleFont(size: metrics.calendarTitleFontSize))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)

            PanelButtonGroup(spacing: EquinoxDesign.spacingXS) {
                PanelDateButton(
                    day: appState.events.todayDate.day,
                    help: String(localized: "Go to Today   T", comment: ""),
                    accessibilityLabel: String(localized: "Go to Today", comment: ""),
                    isSelected: appState.events.selectedDate == appState.events.todayDate,
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    appState.goToToday()
                }
                .keyboardShortcut("t", modifiers: [])

                PanelIconButton(
                    symbol: "plus",
                    help: String(localized: "New Event   ⌘N", comment: ""),
                    accessibilityLabel: String(localized: "New Event", comment: ""),
                    isProminent: true,
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    appState.panel.newEventInitialDate = appState.events.selectedDate
                    appState.panel.isNewEventSheetPresented = true
                }
                .keyboardShortcut("n", modifiers: .command)

                PanelIconButton(
                    symbol: appState.isPinned ? "pin.fill" : "pin",
                    help: appState.isPinned
                        ? String(localized: "Unpin Equinox   P", comment: "Pin button help when pinned")
                        : String(localized: "Pin Equinox   P", comment: ""),
                    accessibilityLabel: appState.isPinned
                        ? String(localized: "Unpin Equinox", comment: "")
                        : String(localized: "Pin Equinox", comment: ""),
                    isSelected: appState.isPinned,
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    appState.togglePinnedState()
                }
                .sensoryFeedback(.selection, trigger: appState.isPinned)
                .keyboardShortcut("p", modifiers: [])

                PanelIconMenuButton(
                    symbol: "ellipsis",
                    help: String(localized: "More actions", comment: ""),
                    accessibilityLabel: String(localized: "More actions", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    Button(String(localized: "Go to Today", comment: "")) {
                        appState.goToToday()
                    }
                    .keyboardShortcut("t", modifiers: [])
                    Divider()
                    Toggle(
                        String(localized: "Show agenda", comment: "Agenda visibility setting"),
                        isOn: showsAgendaBinding
                    )
                    Divider()
                    Button(String(localized: "Preferences…", comment: "")) {
                        SettingsActivationHandler.openSettings(appState: appState)
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    Divider()
                    Button(String(localized: "Quit Equinox", comment: "")) {
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            }
        }
        .padding(.vertical, EquinoxDesign.spacingXS)
        .frame(height: EquinoxDesign.commandBarHeight)
        .overlay(alignment: .bottom) {
            ZStack {
                Rectangle()
                    .fill(EquinoxDesign.ColorToken.separator)
                    .frame(height: 1)
                if appState.events.shouldShowLoadingIndicator {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                        .tint(EquinoxDesign.ColorToken.action)
                        .accessibilityLabel(String(localized: "Loading events", comment: ""))
                }
            }
        }
        .padding(.bottom, EquinoxDesign.spacingXS)
    }

    private var showsAgendaBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.showsAgenda },
            set: { appState.preferences.showsAgenda = $0 }
        )
    }
}
