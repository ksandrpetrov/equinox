import SwiftUI

struct PanelCommandBar: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics

    private var displayedMonthDate: Date {
        appState.events.monthDate.date(in: appState.calendar)
    }

    private var monthTitle: String {
        EquinoxFormatters.formatter(key: "month.standalone") { $0.dateFormat = "LLLL" }
            .string(from: displayedMonthDate)
    }

    private var yearTitle: String {
        EquinoxFormatters.formatter(key: "year.numeric") { $0.dateFormat = "yyyy" }
            .string(from: displayedMonthDate)
    }

    private var monthSymbols: [String] {
        let symbols = EquinoxFormatters.formatter(key: "month.standalone.symbols") { _ in }
            .standaloneMonthSymbols ?? []
        return Array(symbols.prefix(12))
    }

    var body: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            monthMenu
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

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

    private var monthMenu: some View {
        Menu {
            Button {
                navigateByMonths(-12)
            } label: {
                Label(String(localized: "Previous year", comment: "Month navigator action"), systemImage: "chevron.backward.2")
            }
            .disabled(appState.events.selectedDate.year <= CalendarDate.minYear)

            Button {
                appState.goToToday()
            } label: {
                Label(String(localized: "Go to Today", comment: ""), systemImage: "calendar")
            }

            Button {
                navigateByMonths(12)
            } label: {
                Label(String(localized: "Next year", comment: "Month navigator action"), systemImage: "chevron.forward.2")
            }
            .disabled(appState.events.selectedDate.year >= CalendarDate.maxYear)

            Divider()

            ForEach(Array(monthSymbols.enumerated()), id: \.offset) { index, name in
                Button {
                    navigateToMonth(index)
                } label: {
                    if index == appState.events.monthDate.monthIndex {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            HStack(spacing: EquinoxDesign.spacingXS) {
                Text(monthTitle)
                    .font(EquinoxDesign.calendarTitleFont(size: metrics.calendarTitleFontSize))
                Text(yearTitle)
                    .font(EquinoxDesign.calendarYearFont(size: metrics.calendarTitleFontSize))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, EquinoxDesign.spacingSM)
            .frame(maxWidth: .infinity, minHeight: metrics.toolbarButtonSize, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(PanelButtonStyle())
        .help(String(localized: "Choose month", comment: "Month navigator help"))
        .accessibilityLabel("\(monthTitle) \(yearTitle)")
        .accessibilityHint(String(localized: "Choose month", comment: "Month navigator help"))
        .accessibilityAddTraits(.isHeader)
    }

    private func navigateToMonth(_ monthIndex: Int) {
        let delta = monthIndex - appState.events.selectedDate.monthIndex
        navigateByMonths(delta)
    }

    private func navigateByMonths(_ delta: Int) {
        let target = appState.events.selectedDate.addingMonthsPreservingDay(
            delta,
            calendar: appState.calendar
        )
        appState.selectDate(target)
    }

    private var showsAgendaBinding: Binding<Bool> {
        Binding(
            get: { appState.preferences.showsAgenda },
            set: { appState.preferences.showsAgenda = $0 }
        )
    }
}
