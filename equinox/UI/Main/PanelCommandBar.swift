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
            PanelButtonGroup(spacing: 2) {
                PanelIconButton(
                    symbol: "chevron.left",
                    help: String(localized: "Previous month", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    withAnimation(EquinoxDesign.monthTransitionAnimation) {
                        appState.events.goToPreviousMonth()
                    }
                }
                .symbolEffect(.bounce, value: appState.events.monthDate)
                PanelIconButton(
                    symbol: "chevron.right",
                    help: String(localized: "Next month", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    withAnimation(EquinoxDesign.monthTransitionAnimation) {
                        appState.events.goToNextMonth()
                    }
                }
            }

            Button {
                appState.panel.isGoToDateSheetPresented = true
            } label: {
                Text(monthTitle)
                    .font(EquinoxDesign.panelTitleFont())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(String(localized: "Go to Date…", comment: ""))
            .accessibilityLabel(monthTitle)
            .accessibilityHint(String(localized: "Go to Date…", comment: ""))

            PanelButtonGroup(spacing: EquinoxDesign.spacingXS) {
                PanelIconButton(
                    symbol: "calendar.circle",
                    help: String(localized: "Go to Today   T", comment: ""),
                    accessibilityLabel: String(localized: "Go to Today", comment: ""),
                    buttonSize: metrics.toolbarButtonSize
                ) {
                    withAnimation(EquinoxDesign.monthTransitionAnimation) {
                        appState.events.goToToday()
                    }
                }
                .keyboardShortcut("t")

                Button {
                    appState.panel.newEventInitialDate = appState.events.selectedDate
                    appState.panel.isNewEventSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(String(localized: "New Event   ⌘N", comment: ""))
                .accessibilityLabel(String(localized: "New Event", comment: ""))
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
                .keyboardShortcut("p")

                overflowMenu
            }
        }
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.spacingXS)
        .panelCommandBarBackground()
        .frame(height: EquinoxDesign.commandBarHeight)
        .padding(.bottom, EquinoxDesign.spacingXS)
    }

    private var overflowMenu: some View {
        Menu {
            Button(String(localized: "Go to Today", comment: "")) {
                appState.events.goToToday()
            }
            .keyboardShortcut("t")
            Button(String(localized: "Go to Date…", comment: "")) {
                appState.panel.isGoToDateSheetPresented = true
            }
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
        } label: {
            Image(systemName: "ellipsis")
                .symbolRenderingMode(.hierarchical)
                .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .buttonStyle(PanelButtonStyle())
        .help(String(localized: "More actions", comment: ""))
        .accessibilityLabel(String(localized: "More actions", comment: ""))
    }
}
