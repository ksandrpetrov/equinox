import SwiftUI
import XCTest
@testable import EquinoxKit

final class ComponentRenderingTests: XCTestCase {
    @MainActor
    func testMenuBarIconsRenderForEveryStyleAndMeetingState() throws {
        let suite = "equinox.graphics.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter())
        prefs.showMeetingIndicator = true
        for style in MenuBarIconStyle.allCases {
            prefs.menuBarIconType = style.rawValue
            for meeting in [false, true] {
                let image = try XCTUnwrap(MenuBarIconRenderer.iconImage(text: "12", prefs: prefs, shouldShowMeetingIndicator: meeting, scale: 2))
                XCTAssertTrue(image.isTemplate)
                XCTAssertGreaterThan(image.size.width, 0)
                XCTAssertGreaterThan(image.size.height, 0)
            }
        }
        XCTAssertNotNil(MenuBarIconRenderer.meetingIndicatorImage(scale: 2))
    }

    @MainActor
    func testFrameworkResourcesAreAvailableOutsideApplicationBundle() throws {
        XCTAssertNotEqual(Bundle.equinox.bundleURL, Bundle.main.bundleURL)
        XCTAssertNotNil(Bundle.equinox.image(forResource: "AppLogo"))
        for name in ["AccentColor", "OnAccentForeground", "WeekendTint"] {
            XCTAssertNotNil(NSColor(named: name, bundle: .equinox))
        }
    }

    /// Render production components with synthetic content; attachments support visual review.
    @MainActor
    func testCalendarAndAgendaRenderAcrossSizesAndThemes() throws {
        let calendar = Calendar.equinoxGregorian()
        let day = CalendarDate(year: 2026, monthIndex: 8, day: 8)
        let start = day.date(in: calendar).addingTimeInterval(9 * 3600)
        let event = DayEvent(
            id: "design-preview", eventIdentifier: nil, calendarItemIdentifier: "design-preview",
            title: "Обсуждение запуска новой версии приложения", location: "Переговорная • Москва",
            notes: nil, url: nil, startDate: start, endDate: start.addingTimeInterval(3600),
            slotStartDate: start, slotEndDate: start.addingTimeInterval(3600),
            isEventAllDay: false, isSlotAllDay: false, joinURL: nil,
            calendarIdentifier: "work", calendarTitle: "Рабочий календарь команды",
            calendarColorRed: 0.25, calendarColorGreen: 0.5, calendarColorBlue: 0.75,
            calendarColorAlpha: 1, isRecurring: false, allowsContentModifications: false,
            participationStatus: nil
        )
        for size in SizePreference.allCases {
            let metrics = SizeMetrics.metrics(for: size)
            for scheme in [ColorScheme.light, .dark] {
                let content = VStack(spacing: EquinoxDesign.spacingSM) {
                    HStack(spacing: EquinoxDesign.spacingXS) {
                        ForEach(0..<7) { index in
                            DayCellView(
                                date: CalendarDate(year: 2026, monthIndex: 8, day: index + 7),
                                isToday: index == 1, isSelected: index == 2,
                                isKeyboardFocused: index == 2, isInCurrentMonth: index != 0,
                                isHighlighted: index >= 5,
                                isMonthBoundaryStart: false, isMonthBoundaryEnd: false,
                                eventCount: 5, dotColors: [.blue, .green, .orange],
                                metrics: metrics, calendar: calendar, onSelect: {}, onDoubleClick: {}
                            )
                        }
                    }
                    AgendaSectionHeader(date: day, calendar: calendar, metrics: metrics,
                                        eventCount: 2, isSelected: true)
                    AgendaEventCard(event: event, metrics: metrics, showLocation: false, now: start)
                    AgendaEventCard(event: event, metrics: metrics, showLocation: true, now: start.addingTimeInterval(-3600))
                }
                .padding(EquinoxDesign.panelPadding)
                .frame(width: metrics.panelWidth)
                .background(EquinoxDesign.ColorToken.surfaceWindow)
                .environment(\.colorScheme, scheme)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                for showsLocation in [false, true] {
                    let row = AgendaEventCard(event: event, metrics: metrics, showLocation: showsLocation, now: start)
                        .frame(width: metrics.panelWidth - EquinoxDesign.panelPadding * 2)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                    let rowImage = try XCTUnwrap(ImageRenderer(content: row).nsImage)
                    XCTAssertLessThan(rowImage.size.height, metrics.agendaRowMinHeight * 2,
                                      "A long title must not wrap the relative-time badge vertically")
                }
                try exportDesignPreview(content, name: "components-\(size.rawValue)-\(scheme)", width: metrics.panelWidth)
                let details = VStack(alignment: .leading, spacing: EquinoxDesign.spacingLG) {
                    EventDetailHeroHeader(event: event)
                    EventDetailMetadataCard(rows: [
                        EventDetailMetadataRowModel(symbol: "clock", title: "Когда", value: "8 сентября, 09:00–10:00"),
                        EventDetailMetadataRowModel(symbol: "mappin", title: "Место", value: "Переговорная • Москва")
                    ])
                    EventDetailNotesCard(notes: "Обсудить готовность релиза и результаты проверки интерфейса.")
                }
                .padding(ModalDesign.contentPadding)
                .frame(width: metrics.sheetWidth)
                .background(EquinoxDesign.ColorToken.surfaceWindow)
                .environment(\.colorScheme, scheme)
                try exportDesignPreview(details, name: "details-\(size.rawValue)-\(scheme)", width: metrics.sheetWidth)
            }
        }
    }

    @MainActor
    private func exportDesignPreview<Content: View>(_ content: Content, name: String, width: CGFloat) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        XCTAssertEqual(image.size.width, width, accuracy: 1)
        XCTAssertGreaterThan(image.size.height, 0)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("equinox-design-previews")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: folder.appendingPathComponent(name + ".png"))
    }

}
