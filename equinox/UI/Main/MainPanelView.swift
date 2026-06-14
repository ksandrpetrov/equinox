import SwiftUI
import Pow

struct MainPanelView: View {
    @Bindable var appState: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var agendaHeightRatio: Double = PreferencesStore.shared.agendaHeightRatio
    @State private var expandedEventID: String?

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
        let maxHeight = appState.panelAgendaMaxHeight
        return max(120, min(maxHeight, maxHeight * agendaHeightRatio / 0.35))
    }

    var body: some View {
        panelContent
            .panelBackground(style: backgroundStyle, reduceTransparency: reduceTransparency)
            .frame(width: metrics.panelWidth)
            .sheet(isPresented: modalSheetBinding(\.isNewEventSheetPresented)) {
                NewEventSheet(appState: appState, metrics: metrics)
                    .equinoxSheetPresentation()
            }
            .sheet(isPresented: modalSheetBinding(\.isGoToDateSheetPresented)) {
                GoToDateSheet(appState: appState, metrics: metrics)
                    .equinoxSheetPresentation()
            }
            .sheet(isPresented: modalSheetBinding(\.isEventDetailPresented)) {
                if let event = appState.selectedEvent {
                    EventDetailView(appState: appState, event: event, metrics: metrics)
                        .equinoxSheetPresentation()
                }
            }
            .onChange(of: agendaHeightRatio) { _, newValue in
                appState.preferences.agendaHeightRatio = newValue
            }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            PanelCommandBar(appState: appState, metrics: metrics)

            if let feedback = appState.panelFeedback {
                ModalErrorBanner(message: feedback)
                    .padding(.bottom, EquinoxDesign.spacingXS)
                    .onTapGesture {
                        appState.panelFeedback = nil
                    }
            }

            if appState.isFetchingEvents {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, EquinoxDesign.spacingXS)
                    .accessibilityLabel(String(localized: "Loading events", comment: ""))
            }

            PanelStateOverlay(appState: appState)
                .padding(.bottom, EquinoxDesign.spacingXS)

            CalendarGridView(appState: appState, metrics: metrics)
                .fixedSize(horizontal: false, vertical: true)
                .id(appState.monthDate)
                .transition(monthGridTransition)

            if showAgenda {
                PanelSplitDivider(agendaHeightRatio: $agendaHeightRatio)
                AgendaView(
                    appState: appState,
                    metrics: metrics,
                    height: computedAgendaHeight,
                    expandedEventID: $expandedEventID
                )
            }
        }
        .padding(EquinoxDesign.panelPadding)
        .onAppear {
            agendaHeightRatio = appState.preferences.agendaHeightRatio
            appState.refreshPlaudMatchesIfNeeded()
        }
        .animation(EquinoxDesign.animation(EquinoxDesign.monthTransitionAnimation, reduceMotion: reduceMotion), value: appState.monthDate)
    }

    private var monthGridTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .movingParts.blur.combined(with: .opacity),
            removal: .movingParts.blur.combined(with: .opacity)
        )
    }

    private func modalSheetBinding(_ keyPath: ReferenceWritableKeyPath<AppState, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { newValue in
                let wasPresented = appState[keyPath: keyPath]
                appState[keyPath: keyPath] = newValue
                if wasPresented, !newValue {
                    appState.onModalSheetDismissed?()
                }
            }
        )
    }
}
