import Foundation

/// Shared bridge command validation for `EventKitBridge` and contract tests.
enum BridgeCommandValidation {
    static func endIsAfterStart(start: Date, end: Date) -> Bool {
        end > start
    }

    static func bridgeUpdateHasMutableField(
        title: String?,
        startDate: String?,
        endDate: String?,
        allDay: Bool?,
        location: String?,
        notes: String?,
        url: String?,
        calendarId: String?
    ) -> Bool {
        let mutable = Set(BridgeCommandNames.updateMutableFields)
        let presentFields: [(String, Bool)] = [
            ("title", title != nil),
            ("startDate", startDate != nil),
            ("endDate", endDate != nil),
            ("allDay", allDay != nil),
            ("location", location != nil),
            ("notes", notes != nil),
            ("url", url != nil),
            ("calendarId", calendarId != nil),
        ]
        return presentFields.contains { mutable.contains($0.0) && $0.1 }
    }
}
