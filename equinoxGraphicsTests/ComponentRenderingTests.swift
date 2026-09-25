import SwiftUI
import XCTest
@testable import EquinoxKit

final class ComponentRenderingTests: XCTestCase {
    @MainActor
    func testWeekdayLabelsHaveReadableContrastOnPanelSurface() throws {
        func sample(_ color: Color, scheme: ColorScheme) throws -> NSColor {
            let renderer = ImageRenderer(content: color.frame(width: 8, height: 8)
                .background(EquinoxDesign.ColorToken.surfaceWindow)
                .environment(\.colorScheme, scheme))
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            return try XCTUnwrap(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.sRGB))
        }
        for scheme in [ColorScheme.light, .dark] {
            let foreground = try luminance(sample(EquinoxDesign.ColorToken.weekdayDimmed, scheme: scheme))
            let background = try luminance(sample(EquinoxDesign.ColorToken.surfaceWindow, scheme: scheme))
            let ratio = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "Small weekday and week-number labels must remain readable in \(scheme)")
        }
    }

    @MainActor
    func testErrorAndWarningMessagesHaveReadableContrast() throws {
        for scheme in [ColorScheme.light, .dark] {
            for style in [EquinoxBannerStyle.error, .warning] {
                for presentation in [EquinoxBannerPresentation.card, .filled] {
                    let content = EquinoxBanner(message: "Calendar error details", style: style, presentation: presentation)
                        .frame(width: 320)
                        .background(EquinoxDesign.ColorToken.surfaceWindow)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: content)
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
                    let background = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh - 3)?.usingColorSpace(.sRGB))
                    let backgroundLuminance = luminance(background)
                    var strongestGlyphContrast = 1.0
                    // Exclude the decorative icon, border and padding. Test the
                    // interior of the rendered text rather than antialiased edges.
                    for y in 8..<(bitmap.pixelsHigh - 8) {
                        for x in 48..<280 {
                            let pixel = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                            let foreground = luminance(pixel)
                            let ratio = (max(foreground, backgroundLuminance) + 0.05)
                                / (min(foreground, backgroundLuminance) + 0.05)
                            strongestGlyphContrast = max(strongestGlyphContrast, ratio)
                        }
                    }
                    XCTAssertGreaterThanOrEqual(strongestGlyphContrast, 4.5, "\(style), \(presentation), \(scheme)")
                    try exportDesignPreview(content, name: "banner-\(style)-\(presentation)-\(scheme)", width: 320)
                }
            }
        }
    }

    @MainActor
    private func luminance(_ color: NSColor) -> Double {
        func linear(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return linear(color.redComponent) * 0.2126
            + linear(color.greenComponent) * 0.7152
            + linear(color.blueComponent) * 0.0722
    }

    @MainActor
    func testSurfaceColorsAdaptToLightAndDarkAppearance() throws {
        let colors = [
            EquinoxDesign.ColorToken.surfacePrimary,
            EquinoxDesign.ColorToken.surfaceSecondary,
            EquinoxDesign.ColorToken.surfaceWindow,
            EquinoxDesign.ColorToken.surfaceRaised,
        ]
        for color in colors {
            var brightness: [CGFloat] = []
            for scheme in [ColorScheme.light, .dark] {
                let renderer = ImageRenderer(content: color.frame(width: 8, height: 8).environment(\.colorScheme, scheme))
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
                let sample = try XCTUnwrap(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.sRGB))
                XCTAssertGreaterThan(sample.alphaComponent, 0.99)
                brightness.append((sample.redComponent + sample.greenComponent + sample.blueComponent) / 3)
            }
            XCTAssertGreaterThan(brightness[0] - brightness[1], 0.2, "Surface must visibly adapt to the appearance")
        }
    }

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
        for scheme in [ColorScheme.light, .dark] {
            prefs.showMonthInIcon = true
            prefs.showDayOfWeekInIcon = true
            prefs.menuBarIconType = MenuBarIconStyle.classic.rawValue
            let picker = MenuBarIconPicker(prefs: prefs)
                .padding(EquinoxDesign.spacingLG)
                .frame(width: 500)
                .background(EquinoxDesign.ColorToken.surfaceWindow)
                .environment(\.colorScheme, scheme)
            try exportDesignPreview(picker, name: "menu-bar-icons-\(scheme)", width: 500)
        }
    }

    @MainActor
    func testFrameworkResourcesAreAvailableOutsideApplicationBundle() throws {
        XCTAssertNotEqual(Bundle.equinox.bundleURL, Bundle.main.bundleURL)
        XCTAssertNotNil(Bundle.equinox.image(forResource: "AppLogo"))
        let language = Bundle.preferredLocalizations(from: ["en", "ru"], forPreferences: Locale.preferredLanguages).first
        XCTAssertEqual(String(localized: "New Event", bundle: .equinox),
                       language == "ru" ? "Новое событие" : "New Event",
                       "The graphics host must render the requested language, including framework strings")
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
