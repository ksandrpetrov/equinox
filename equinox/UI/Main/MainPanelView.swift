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

    private var showAgenda: Bool {
        appState.preferences.showEventDays > 0
    }

    private var computedAgendaHeight: CGFloat {
        guard showAgenda else { return 0 }
        return AgendaLayout.agendaHeight(
            maxHeight: appState.layout.panelAgendaMaxHeight,
            heightRatio: appState.preferences.agendaHeightRatio
        )
    }

    var body: some View {
        panelContent
            .panelBackground(style: backgroundStyle, reduceTransparency: reduceTransparency)
            .frame(width: metrics.panelWidth)
            .sheet(isPresented: modalSheetBinding(\.panel.isNewEventSheetPresented)) {
                NewEventSheet(appState: appState, metrics: metrics)
                    .equinoxSheetPresentation()
            }
            .sheet(isPresented: modalSheetBinding(\.panel.isEventDetailPresented)) {
                if let event = appState.panel.selectedEvent {
                    EventDetailView(appState: appState, event: event, metrics: metrics)
                        .equinoxSheetPresentation()
                }
            }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            PanelCommandBar(appState: appState, metrics: metrics)

            if let feedback = appState.panel.panelFeedback {
                EquinoxBanner(
                    message: feedback,
                    style: .error,
                    actionTitle: String(localized: "Dismiss", comment: "Panel error dismiss action"),
                    action: { appState.panel.panelFeedback = nil }
                )
                    .padding(.bottom, EquinoxDesign.spacingXS)
            }

            loadingSlot

            PanelStateOverlay(appState: appState)
                .padding(.bottom, EquinoxDesign.spacingXS)

            CalendarGridView(appState: appState, metrics: metrics)
                .fixedSize(horizontal: false, vertical: true)

            if showAgenda {
                AgendaView(
                    appState: appState,
                    metrics: metrics,
                    height: computedAgendaHeight
                )
                .padding(.top, EquinoxDesign.spacingSM)
            }
        }
        .padding(EquinoxDesign.panelPadding)
        .onAppear {
            appState.plaud.refreshMatchesIfNeeded()
        }
    }

    private var loadingSlot: some View {
        HStack {
            Spacer(minLength: 0)
            ProgressView()
                .controlSize(.small)
                .opacity(appState.events.shouldShowLoadingIndicator ? 1 : 0)
                .accessibilityHidden(!appState.events.shouldShowLoadingIndicator)
                .accessibilityLabel(String(localized: "Loading events", comment: ""))
            Spacer(minLength: 0)
        }
        .frame(height: metrics.loadingIndicatorHeight)
        .padding(.bottom, EquinoxDesign.spacingXS)
    }

    private func modalSheetBinding(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { newValue in
                let wasPresented = appState[keyPath: keyPath]
                appState[keyPath: keyPath] = newValue
                if wasPresented, !newValue {
                    appState.panel.onModalSheetDismissed?()
                }
            }
        )
    }
}
