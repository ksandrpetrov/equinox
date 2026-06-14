import Foundation

@Observable
@MainActor
final class PanelPresentationState {
    var isPanelVisible = false
    /// Bumped each time the panel becomes visible so the agenda re-scrolls to the selected day.
    /// The hosting controller is reused across show/hide, so `onAppear` alone does not re-fire on reopen.
    var agendaScrollGeneration = 0
    var isNewEventSheetPresented = false
    var newEventInitialDate: CalendarDate?
    var selectedEvent: DayEvent?
    var isEventDetailPresented = false
    var panelFeedback: String?
    var settingsInitialTab: SettingsTab = .general

    var onPinStateChanged: (() -> Void)?
    var onModalSheetDismissed: (() -> Void)?

    var isModalSheetPresented: Bool {
        isNewEventSheetPresented || isEventDetailPresented
    }
}
