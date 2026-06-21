import Foundation

/// Documents intentional output differences between GUI (`CalendarStore`) and bridge/MCP.
/// Contract tests assert these flags stay stable when refactoring either path.
enum AppBridgeEventContract {
    static let bridgeFiltersDeclinedInvitations = true
    static let guiShowsDeclinedInvitationsDimmed = true
    static let bridgeUsesFlatEvents = true
    static let guiUsesEventLayoutDaySlots = true
    static let bridgeJoinURLIsWebOnly = true
    static let guiJoinURLMayRewriteToNative = true
    static let bridgeListsAllDisplayableCalendarsByDefault = true
    static let guiRespectsCalendarSelectionStorage = true
    static let bridgeSupportsUpdateEvent = true
    static let guiSupportsUpdateEvent = false
    static let bridgeSupportsRSVPWrite = false
    static let guiSupportsRSVPWrite = true

    static let bridgeDeleteEventSupportsFutureSpan = true
    static let guiDeleteEventSpanIsThisEventOnly = true
    static let bridgeCreateEventFieldsAreMinimal = true
    static let guiCreateEventSupportsRecurrenceAlarmsTimezone = true
    static let declinedInvitationVisibleInGUIListButNotDeletable = true
}
