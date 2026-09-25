import AppKit
import SwiftUI
import XCTest
@testable import EquinoxKit

@MainActor
final class SurfaceLayoutTests: XCTestCase {
    func testEventDrawerPreservesCalendarHeightAndWindowRightEdge() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        state.isPinned = true
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let controller = PanelWindowController(appState: state)
        defer { controller.hide() }
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            controller.show(statusItem: statusItem, isPinned: true)
            controller.handleSizePreferenceChanged(statusItem: statusItem)
            try await Task.sleep(for: .milliseconds(300))
            let window = try XCTUnwrap(controller.window)
            let screen = try XCTUnwrap(window.screen).visibleFrame
            window.setFrameOrigin(NSPoint(x: screen.maxX - metrics.panelWidth - EquinoxDesign.panelScreenMargin,
                                          y: screen.maxY - window.frame.height - EquinoxDesign.panelScreenMargin))
            let collapsed = window.frame
            let content = try XCTUnwrap(window.contentView)
            let geometry = WindowGeometryProbe()
            content.postsFrameChangedNotifications = true
            let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: content, queue: .main) { _ in
                MainActor.assumeIsolated {
                    geometry.maximumWidthMismatch = max(geometry.maximumWidthMismatch,
                        abs(content.frame.width - window.contentLayoutRect.width))
                }
            }
            state.panel.isNewEventSheetPresented = true
            try await Task.sleep(for: .milliseconds(500))
            let expanded = window.frame
            XCTAssertEqual(expanded.width, metrics.panelWidth + metrics.sheetWidth, accuracy: 1)
            XCTAssertEqual(expanded.height, collapsed.height, accuracy: 1, "The form must scroll within the calendar height")
            XCTAssertEqual(expanded.maxX, collapsed.maxX, accuracy: 1, "The drawer expands to the left")
            XCTAssertEqual(expanded.maxY, collapsed.maxY, accuracy: 1)
            XCTAssertNil(window.attachedSheet, "Creating an event must not cover the calendar with a sheet")
            state.dismissEventDrawer()
            try await Task.sleep(for: .milliseconds(500))
            XCTAssertEqual(window.frame.width, metrics.panelWidth, accuracy: 1)
            XCTAssertEqual(window.frame.maxX, collapsed.maxX, accuracy: 1)
            NotificationCenter.default.removeObserver(observer)
            XCTAssertLessThanOrEqual(geometry.maximumWidthMismatch, 1, "Content must resize with the window, without an intermediate jump")
        }
    }

    func testAppearanceSegmentsRemainInsideSettingsContent() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let width = SettingsDesign.windowMinWidth - SettingsDesign.sidebarWidth
        let view = NSHostingView(rootView: AppearanceSettingsTab(searchText: "Theme", prefs: context.appState.preferences))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.contentView = nil }
        view.frame = NSRect(x: 0, y: 0, width: width, height: 400)
        view.layoutSubtreeIfNeeded()
        await Task.yield()
        view.layoutSubtreeIfNeeded()

        func segmentedControls(in parent: NSView) -> [NSSegmentedControl] {
            parent.subviews.flatMap { child in
                (child as? NSSegmentedControl).map { [$0] } ?? segmentedControls(in: child)
            }
        }
        let controls = segmentedControls(in: view)
        XCTAssertEqual(controls.count, 3)
        for control in controls {
            let frame = control.convert(control.bounds, to: view)
            XCTAssertGreaterThanOrEqual(frame.minX, SettingsDesign.detailPadding - 1)
            XCTAssertLessThanOrEqual(frame.maxX, width - SettingsDesign.detailPadding + 1,
                                     "Segmented options must not overflow their row: \(frame)")
        }
    }

    func testDrawersAcrossSizesBackgroundsAndAppearances() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let event = context.event(start: Date(), title: "Very long event title — Обсуждение запуска новой версии приложения и планов команды",
                                  location: "Long meeting location — Переговорная на четвёртом этаже")
        let day = CalendarDate(date: event.startDate, calendar: state.calendar)
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await state.events.syncFromCalendarStore()
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            for background in [BackgroundStyle.glass, .solid] {
                state.preferences.backgroundStyle = background.rawValue
                for scheme in [ColorScheme.light, .dark] {
                    state.panel.isNewEventSheetPresented = true
                    try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                                    width: metrics.panelWidth + metrics.sheetWidth, height: 850, scheme: scheme,
                                    name: "drawer-create-\(size)-\(background)-\(scheme)")
                    state.panel.isNewEventSheetPresented = false
                    state.panel.selectedEvent = event
                    state.panel.isEventDetailPresented = true
                    try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                                    width: metrics.panelWidth + metrics.sheetWidth, height: 850, scheme: scheme,
                                    name: "drawer-details-\(size)-\(background)-\(scheme)")
                    XCTAssertTrue(state.panel.isEventDetailPresented)
                    state.dismissEventDrawer()
                }
            }
        }
    }

    func testPermissionLoadingEmptyAndErrorSurfaces() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let scenarios: [(String, CalendarStoreSnapshot)] = [
            ("not-determined", StubCalendarEventStore.snapshot(status: .notDetermined)),
            ("denied", StubCalendarEventStore.snapshot(status: .denied)),
            ("restricted", StubCalendarEventStore.snapshot(status: .restricted)),
            ("loading", StubCalendarEventStore.snapshot(status: .authorized, hasCompletedInitialLoad: false)),
            ("empty", StubCalendarEventStore.snapshot(status: .authorized, hasSelectedCalendars: false)),
            ("error", StubCalendarEventStore.snapshot(status: .authorized, lastFetchError: "Unable to load calendars. Повторите попытку после восстановления доступа к календарям."))
        ]
        for (name, snapshot) in scenarios {
            context.store.readSnapshot = { snapshot }
            await state.events.syncFromCalendarStore()
            state.events.shouldShowLoadingIndicator = name == "loading"
            for size in SizePreference.allCases {
                state.preferences.sizePreference = size.rawValue
                for scheme in [ColorScheme.light, .dark] {
                    try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                                    width: SizeMetrics.metrics(for: size).panelWidth, height: 900, scheme: scheme,
                                    name: "state-\(name)-\(size)-\(scheme)")
                }
            }
        }
    }

    func testTodayPlacesDayHeaderAtTopOfAgenda() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let today = state.events.todayDate
        var events: [CalendarDate: [DayEvent]] = [:]
        for offset in -5...40 {
            let day = today.addingDays(offset)
            events[day] = (9...13).map { hour in
                context.event(start: day.date(in: state.calendar).addingTimeInterval(Double(hour) * 3600))
            }
        }
        events[today]?.append(context.event(start: Date().addingTimeInterval(-300)))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await context.finishInitialization()
        state.panel.isPanelVisible = true
        state.goToNextMonth()

        let geometry = AgendaGeometryProbe()
        let metrics = SizeMetrics.metrics(for: .medium)
        let view = NSHostingView(rootView: AgendaView(appState: state, metrics: metrics, height: 280)
            .onPreferenceChange(AgendaSectionFramesKey.self) { frames in
                Task { @MainActor in geometry.frames = frames }
            })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: metrics.panelWidth, height: 320),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil); window.contentView = nil }
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(350))

        state.goToToday()
        try await Task.sleep(for: .milliseconds(350))
        view.layoutSubtreeIfNeeded()
        let header = try XCTUnwrap(geometry.frames[today])
        XCTAssertEqual(header.minY, 0, accuracy: 1, "Today must align its section header with the top of the scroll viewport")
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "today-at-agenda-top"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRapidMonthNavigationWithPopulatedAgenda() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let start = CalendarDate(year: 2026, monthIndex: 0, day: 15)
        var events: [CalendarDate: [DayEvent]] = [:]
        for offset in -30...800 {
            let day = start.addingDays(offset)
            events[day] = (9...13).map { hour in
                context.event(start: day.date(in: state.calendar).addingTimeInterval(Double(hour) * 3600))
            }
        }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await context.finishInitialization()
        state.preferences.showDaysWithNoEvents = true
        state.panel.isPanelVisible = true
        state.selectDate(start)

        let view = NSHostingView(rootView: MainPanelView(appState: state))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 800),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil); window.contentView = nil }
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        let fetchesBeforeNavigation = context.store.fetchedRanges.count

        var frameDurations: [Double] = []
        for _ in 0..<24 {
            let began = Date.timeIntervalSinceReferenceDate
            state.goToNextMonth()
            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            frameDurations.append(Date.timeIntervalSinceReferenceDate - began)
            try await Task.sleep(for: .milliseconds(25))
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.events.selectedDate, start.addingMonthsPreservingDay(24, calendar: state.calendar))
        XCTAssertLessThanOrEqual(context.store.fetchedRanges.count - fetchesBeforeNavigation, 2,
                                 "A burst must load the final month, not fetch and redraw all 24 intermediate agendas")
        let timing = "Month navigation frames (seconds): \(frameDurations); total: \(frameDurations.reduce(0, +)); worst: \(frameDurations.max() ?? 0)"
        print(timing)
        let attachment = XCTAttachment(string: timing)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPanelAndEventSheetsLayoutAcrossSizesAndThemes() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.selectedDate
        let event = context.event(start: day.date(in: state.calendar).addingTimeInterval(11 * 3600),
                                  title: "Обсуждение запуска", location: "Переговорная, 4 этаж", participationStatus: .accepted)
        var events: [CalendarDate: [DayEvent]] = [day: [event]]
        for offset in 1...4 {
            let date = day.addingDays(offset)
            events[date] = [context.event(start: date.date(in: state.calendar), title: "Отпуск", isAllDay: true),
                            context.event(start: date.date(in: state.calendar).addingTimeInterval(13 * 3600), title: "Встреча команды")]
        }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await context.finishInitialization()
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            for scheme in [ColorScheme.light, .dark] {
                try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                          width: metrics.panelWidth, height: 750, scheme: scheme, name: "panel-\(size)-\(scheme)")
                try await check(NewEventSheet(appState: state, metrics: metrics).environment(\.colorScheme, scheme),
                          width: metrics.sheetWidth, height: 750, scheme: scheme, name: "create-\(size)-\(scheme)")
                try await check(EventDetailView(appState: state, event: event, metrics: metrics).environment(\.colorScheme, scheme),
                          width: metrics.sheetWidth, height: 750, scheme: scheme, name: "details-\(size)-\(scheme)")
                try await check(EventDateCalendar(selection: .constant(event.startDate),
                                                  range: EventDraftDefaults.supportedDateRange(calendar: state.calendar),
                                                  calendar: state.calendar, weekStartWeekday: 1, metrics: metrics, onClose: {})
                    .environment(\.colorScheme, scheme),
                                width: metrics.sheetWidth, height: 450, scheme: scheme, name: "date-picker-\(size)-\(scheme)")
            }
        }
    }

    func testEverySettingsTabLayoutsWithInjectedApplicationState() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        for tab in SettingsTab.allCases {
            for scheme in [ColorScheme.light, .dark] {
                context.appState.panel.settingsInitialTab = tab
                try await check(SettingsView(initialTab: tab)
                    .environment(\.appState, context.appState)
                    .environment(\.colorScheme, scheme),
                          width: 850, height: 700, scheme: scheme, name: "settings-\(tab)-\(scheme)")
                XCTAssertEqual(context.appState.panel.settingsInitialTab, tab)
            }
        }
    }

    private func check<Content: View>(_ content: Content, width: CGFloat, height: CGFloat, scheme: ColorScheme, name: String) async throws {
        let view = NSHostingView(rootView: content.background {
            EquinoxSurface(style: .solid, showsBorder: false).environment(\.colorScheme, scheme)
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = view
        defer { window.contentView = nil }
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.layoutSubtreeIfNeeded()
        await Task.yield()
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.fittingSize.width.isFinite)
        XCTAssertTrue(view.fittingSize.height.isFinite)
        XCTAssertGreaterThan(view.fittingSize.width, 0, name)
        XCTAssertGreaterThan(view.fittingSize.height, 0, name)
        XCTAssertLessThanOrEqual(view.fittingSize.width, width + 1, "Horizontal overflow: \(name)")
        XCTAssertLessThanOrEqual(view.fittingSize.height, height + 1, "Vertical overflow: \(name)")
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        var minimumBrightness: CGFloat = 1
        var maximumBrightness: CGFloat = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 32)) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 32)) {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                minimumBrightness = min(minimumBrightness, brightness)
                maximumBrightness = max(maximumBrightness, brightness)
            }
        }
        XCTAssertGreaterThan(maximumBrightness - minimumBrightness, 0.05, "Blank or uniform render: \(name)")
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("equinox-surface-previews")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class AgendaGeometryProbe {
    var frames: [CalendarDate: CGRect] = [:]
}

@MainActor
private final class WindowGeometryProbe {
    var maximumWidthMismatch: CGFloat = 0
}
