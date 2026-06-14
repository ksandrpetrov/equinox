import Foundation

@Observable
@MainActor
final class PanelPresentationState {
    var isPanelVisible = false
    var isNewEventSheetPresented = false
    var newEventInitialDate: CalendarDate?
    var isGoToDateSheetPresented = false
    var selectedEvent: DayEvent?
    var isEventDetailPresented = false
    var panelFeedback: String?
    var settingsInitialTab: SettingsTab = .general

    var onPinStateChanged: (() -> Void)?
    var onModalSheetDismissed: (() -> Void)?

    var isModalSheetPresented: Bool {
        isNewEventSheetPresented || isGoToDateSheetPresented || isEventDetailPresented
    }
}
