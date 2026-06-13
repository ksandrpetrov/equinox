import Foundation

enum EventDraftDefaults {
    static func defaultStartAndEnd(
        calendar: Calendar,
        initialDate: CalendarDate?
    ) -> (start: Date, end: Date) {
        let roundedStart: Date
        if let initial = initialDate {
            var components = calendar.dateComponents([.year, .month, .day], from: initial.date(in: calendar))
            let now = Date()
            let nowHour = calendar.component(.hour, from: now)
            let nowMinute = calendar.component(.minute, from: now)
            components.hour = nowMinute >= 30 ? nowHour + 1 : nowHour
            components.minute = 0
            if let rounded = calendar.date(from: components) {
                roundedStart = rounded
            } else {
                roundedStart = initial.date(in: calendar)
            }
        } else {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let hour = calendar.component(.hour, from: now)
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = minute >= 30 ? hour + 1 : hour
            components.minute = 0
            roundedStart = calendar.date(from: components) ?? now
        }
        let end = calendar.date(byAdding: .minute, value: 60, to: roundedStart) ?? roundedStart
        return (roundedStart, end)
    }
}
