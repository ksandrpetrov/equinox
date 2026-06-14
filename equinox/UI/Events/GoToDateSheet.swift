import SwiftUI

struct GoToDateSheet: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics
    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate = Date()

    private var pickerCalendar: Calendar {
        var calendar = appState.calendar
        calendar.firstWeekday = appState.preferences.weekStartWeekday + 1
        return calendar
    }

    var body: some View {
        ModalSheetScaffold(
            title: String(localized: "Go to Date", comment: ""),
            metrics: metrics,
            confirmTitle: String(localized: "Go", comment: ""),
            minHeight: nil,
            onCancel: { close() },
            onConfirm: { goToPickedDate() }
        ) {
            VStack(spacing: EquinoxDesign.spacingSM) {
                DatePicker(
                    String(localized: "Date", comment: "Go to date picker label"),
                    selection: $pickedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.calendar, pickerCalendar)
                .accessibilityLabel(String(localized: "Date", comment: "Go to date picker label"))

                Button(String(localized: "Today", comment: "")) {
                    pickedDate = appState.events.todayDate.date(in: appState.calendar)
                }
                .buttonStyle(.link)
                .disabled(isShowingToday)
            }
            .padding(.horizontal, EquinoxDesign.spacingLG)
            .padding(.bottom, EquinoxDesign.spacingMD)
        }
        .onAppear {
            pickedDate = appState.events.selectedDate.date(in: appState.calendar)
        }
    }

    private var isShowingToday: Bool {
        appState.calendar.isDate(
            pickedDate,
            inSameDayAs: appState.events.todayDate.date(in: appState.calendar)
        )
    }

    private func close() {
        dismiss()
    }

    private func goToPickedDate() {
        let date = CalendarDate(date: pickedDate, calendar: appState.calendar)
        appState.events.selectDate(date)
        close()
    }
}
