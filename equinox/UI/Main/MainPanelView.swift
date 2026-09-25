import SwiftUI

struct MainPanelView: View {
    @Bindable var appState: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var metrics: SizeMetrics {
        SizeMetrics.metrics(for: SizePreference(rawValue: appState.preferences.sizePreference) ?? .medium)
    }
    private var backgroundStyle: BackgroundStyle {
        BackgroundStyle(rawValue: appState.preferences.backgroundStyle) ?? .glass
    }

    private var computedAgendaHeight: CGFloat {
        guard appState.preferences.showsAgenda else { return 0 }
        return AgendaLayout.agendaHeight(
            maxHeight: appState.layout.panelAgendaMaxHeight,
            heightRatio: appState.preferences.agendaHeightRatio
        )
    }

    private var panelLayoutState: PanelLayoutState {
        PanelLayoutState(
            showsAgenda: appState.preferences.showsAgenda,
            calendarRowCount: appState.preferences.calendarRowCount,
            agendaHeightRatio: appState.preferences.agendaHeightRatio,
            panelFeedback: appState.panel.panelFeedback,
            accessStatus: appState.events.calendarAccessStatus.rawValue,
            hasCompletedInitialLoad: appState.events.hasCompletedInitialEventLoad,
            fetchError: appState.events.lastFetchError,
            hasCalendars: appState.events.hasCalendars,
            hasSelectedCalendars: appState.events.hasSelectedCalendars,
            hasSeenShortcutTip: appState.preferences.hasSeenShortcutTip
        )
    }

    var body: some View {
        panelContent
            .frame(width: metrics.panelWidth)
            .disabled(appState.panel.isModalSheetPresented)
            .padding(.leading, appState.panel.isModalSheetPresented ? metrics.sheetWidth : 0)
            .overlay(alignment: .leading) {
                if appState.panel.isModalSheetPresented {
                    eventDrawer
                        .frame(width: metrics.sheetWidth)
                        .frame(maxHeight: .infinity)
                        .background(alignment: .trailing) {
                            Rectangle()
                                .fill(EquinoxDesign.ColorToken.separator)
                                .frame(width: EquinoxDesign.hairlineWidth)
                        }
                }
            }
            .panelBackground(style: backgroundStyle, reduceTransparency: reduceTransparency)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            .onChange(of: panelLayoutState) { _, _ in
                appState.layout.invalidatePanelSize()
            }
            .onChange(of: appState.panel.isModalSheetPresented) { _, isPresented in
                appState.layout.invalidatePanelSize()
                if !isPresented {
                    appState.panel.onModalSheetDismissed?()
                }
            }
    }

    @ViewBuilder
    private var eventDrawer: some View {
        if appState.panel.isNewEventSheetPresented {
            NewEventSheet(appState: appState, metrics: metrics)
        } else if let event = appState.panel.selectedEvent {
            EventDetailView(appState: appState, event: event, metrics: metrics)
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            PanelCommandBar(appState: appState, metrics: metrics)
                .padding(.bottom, EquinoxDesign.spacingSM)

            if let feedback = appState.panel.panelFeedback {
                EquinoxBanner(
                    message: feedback,
                    style: .error,
                    actionTitle: String(localized: "Dismiss", bundle: .equinox, comment: "Panel error dismiss action"),
                    action: { appState.panel.panelFeedback = nil }
                )
                    .padding(.bottom, EquinoxDesign.spacingXS)
            }

            PanelStateOverlay(appState: appState)
                .padding(.bottom, EquinoxDesign.spacingXS)

            CalendarGridView(appState: appState, metrics: metrics)
                .fixedSize(horizontal: false, vertical: true)

            if appState.preferences.showsAgenda, computedAgendaHeight > 0 {
                AgendaView(
                    appState: appState,
                    metrics: metrics,
                    height: computedAgendaHeight
                )
            }
        }
        .padding(EquinoxDesign.panelPadding)
    }

}

private struct PanelLayoutState: Equatable {
    let showsAgenda: Bool
    let calendarRowCount: Int
    let agendaHeightRatio: Double
    let panelFeedback: String?
    let accessStatus: Int
    let hasCompletedInitialLoad: Bool
    let fetchError: String?
    let hasCalendars: Bool
    let hasSelectedCalendars: Bool
    let hasSeenShortcutTip: Bool
}
