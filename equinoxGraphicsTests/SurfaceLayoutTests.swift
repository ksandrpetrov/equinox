import AppKit
import SwiftUI
import XCTest
@testable import EquinoxKit

@MainActor
final class SurfaceLayoutTests: XCTestCase {
    func testSolidAndExplicitlyReducedTransparencySurfacesRenderOpaqueInBothThemes() async throws {
        let cases: [(style: EquinoxKit.BackgroundStyle, localOverride: Bool)] = [
            (.solid, false), (.glass, true),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for testCase in cases {
                let content = HStack(spacing: 0) {
                    EquinoxSurface(style: testCase.style, cornerRadius: 0, showsBorder: false,
                                   reduceTransparency: testCase.localOverride)
                        .frame(width: 32, height: 32)
                    EquinoxDesign.ColorToken.surfacePrimary.frame(width: 32, height: 32)
                }
                .background(Color(red: 1, green: 0, blue: 1))
                .environment(\.colorScheme, scheme)
                let view = NSHostingView(rootView: content)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 64, height: 32),
                                      styleMask: [.borderless], backing: .buffered, defer: true)
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentView = view
                defer { window.contentView = nil }
                view.layoutSubtreeIfNeeded()
                await Task.yield()
                view.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let actual = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
                let opaque = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide * 3 / 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
                let diagnostic = "\(scheme), \(testCase)"
                XCTAssertEqual(actual.redComponent, opaque.redComponent, accuracy: 2 / 255, diagnostic)
                XCTAssertEqual(actual.greenComponent, opaque.greenComponent, accuracy: 2 / 255, diagnostic)
                XCTAssertEqual(actual.blueComponent, opaque.blueComponent, accuracy: 2 / 255, diagnostic)
                XCTAssertGreaterThan(actual.alphaComponent, 0.99, diagnostic)
            }
        }
    }

    func testSettingsOpeningReusesItsWindowAndForwardsTheRequestedTab() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let application = NSApplication.shared
        let originalPolicy = application.activationPolicy()
        let existingWindows = Set(application.windows.map(ObjectIdentifier.init))
        let identifier = NSUserInterfaceItemIdentifier("equinoxSettingsWindow")
        let unrelated = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        unrelated.identifier = NSUserInterfaceItemIdentifier("unrelated-settings-test-window")
        unrelated.isReleasedWhenClosed = false
        defer {
            for window in application.windows where window.identifier == identifier
                && !existingWindows.contains(ObjectIdentifier(window)) {
                window.identifier = nil
                window.contentViewController = nil
                window.close()
            }
            unrelated.close()
            application.setActivationPolicy(originalPolicy)
        }
        XCTAssertFalse(application.windows.contains { $0.identifier == identifier })
        application.setActivationPolicy(.accessory)
        XCTAssertEqual(application.activationPolicy(), .accessory)

        // Keep opening and reopening in one MainActor turn so desktop focus changes
        // cannot interleave with the visibility contract being checked.
        SettingsActivationHandler.openSettings(appState: context.appState, initialTab: .appearance)
        let settings = application.windows.filter { $0.identifier == identifier }
        XCTAssertEqual(settings.count, 1)
        let window = try XCTUnwrap(settings.first)
        XCTAssertEqual(application.activationPolicy(), .regular)
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(unrelated.isVisible)
        XCTAssertEqual(context.appState.panel.settingsInitialTab, .appearance)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertEqual(content.bounds.width, SettingsDesign.windowMinWidth, accuracy: 1)
        XCTAssertEqual(content.bounds.height, SettingsDesign.windowMinHeight, accuracy: 1)
        // AppKit owns the screen-dependent placement, including its vertical offset.
        // Compare the resulting geometry with an independent, hidden reference window.
        unrelated.setFrame(window.frame, display: false)
        unrelated.center()
        XCTAssertEqual(window.frame.minX, unrelated.frame.minX, accuracy: 1)
        XCTAssertEqual(window.frame.minY, unrelated.frame.minY, accuracy: 1)

        window.setFrameOrigin(NSPoint(x: window.frame.minX + 17, y: window.frame.minY - 23))
        let movedFrame = window.frame
        window.orderOut(nil)
        SettingsActivationHandler.openSettings(appState: context.appState, initialTab: .calendars)
        XCTAssertEqual(application.windows.filter { $0.identifier == identifier }.map(ObjectIdentifier.init),
                       [ObjectIdentifier(window)], "Reopening settings must reuse the existing window")
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(unrelated.isVisible)
        XCTAssertEqual(context.appState.panel.settingsInitialTab, .calendars)
        XCTAssertEqual(window.frame, movedFrame, "Reopening settings must preserve the user's window position")
    }

    func testEarlyLaunchAppliesThemeAndInstallsSettingsCloseHandling() async throws {
        let application = NSApplication.shared
        let originalAppearance = application.appearance
        let originalPolicy = application.activationPolicy()
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        defer {
            window.identifier = nil
            window.close()
            application.appearance = originalAppearance
            application.setActivationPolicy(originalPolicy)
        }

        let expectedAppearance: NSAppearance.Name?
        switch ThemePreference(rawValue: PreferencesStore.shared.themePreference) ?? .system {
        case .light: expectedAppearance = .aqua
        case .dark: expectedAppearance = .darkAqua
        case .system: expectedAppearance = nil
        }
        application.appearance = NSAppearance(named: expectedAppearance == .aqua ? .darkAqua : .aqua)
        let delegate = AppDelegate()
        delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification,
                                                             object: application))
        XCTAssertEqual(application.appearance?.name, expectedAppearance)

        application.setActivationPolicy(.regular)
        XCTAssertEqual(application.activationPolicy(), .regular)
        window.identifier = NSUserInterfaceItemIdentifier("unrelated-graphics-window")
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        XCTAssertEqual(application.activationPolicy(), .regular, "Closing another window must not hide the app")
        window.identifier = NSUserInterfaceItemIdentifier("equinoxSettingsWindow")
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        try await waitUntil("Settings close restores accessory policy") {
            application.activationPolicy() == .accessory
        }
    }

    func testDenseHostedAgendaReleasesViewsAndApplicationState() async throws {
        var released: [@MainActor () -> Bool] = []
        for count in [100, 1_000, 10_000] {
            for repetition in 0..<3 {
                released.append(try await hostDenseAgenda(count: count, repetition: repetition))
            }
        }
        // SwiftUI cancels view tasks and relinquishes its graph on subsequent turns.
        try await waitUntil("Hosted surfaces released") { released.allSatisfy { $0() } }
        XCTAssertTrue(released.allSatisfy { $0() }, "Closed hosted surfaces must release their view and AppState")
    }

    private func hostDenseAgenda(count: Int, repetition: Int) async throws -> @MainActor () -> Bool {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let start = day.date(in: state.calendar)
        let events = (0..<count).map { index in
            context.event(start: start.addingTimeInterval(Double(index)), title: "QA \(index) — длинное название 📅")
        }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: events]) }
        await context.finishInitialization()
        let view = NSHostingView(rootView: MainPanelView(appState: state))
        let width = SizeMetrics.metrics(for: .medium).panelWidth
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 750),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = view
        let clock = ContinuousClock()
        let began = clock.now
        view.layoutSubtreeIfNeeded()
        await Task.yield()
        view.layoutSubtreeIfNeeded()
        let elapsed = began.duration(to: clock.now)
        XCTAssertEqual(state.events.events(for: day).count, count)
        XCTAssertLessThanOrEqual(view.fittingSize.width, width + 1)
        XCTAssertTrue(view.fittingSize.height.isFinite)
        let evidence = XCTAttachment(string: "Hosted \(count) events, repetition \(repetition): initial layout \(elapsed)")
        evidence.name = "hosted-load-\(count)-\(repetition)"
        evidence.lifetime = .keepAlways
        add(evidence)
        window.contentView = nil
        return { [weak view, weak state] in view == nil && state == nil }
    }

    func testDelayedDeletionDoesNotDismissReplacementDrawer() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let day = state.events.todayDate
        let event = context.event(start: day.date(in: state.calendar))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        state.panel.selectedEvent = event
        state.panel.isEventDetailPresented = true
        let metrics = SizeMetrics.metrics(for: .medium)
        let view = NSHostingView(rootView: AnyView(EventDetailView(appState: state, event: event, metrics: metrics)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: metrics.sheetWidth, height: 750),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.orderOut(nil); window.contentView = nil }
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        try await waitForLayout(window)
        let point = NSPoint(x: EquinoxDesign.panelPadding + EquinoxDesign.spacingMD,
                           y: EquinoxDesign.panelPadding + EquinoxDesign.spacingMD)
        let mouseUp = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 0))
        let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.postEvent(mouseUp, atStart: true)
        window.sendEvent(mouseDown)
        try await waitUntil("Deletion confirmation attached") { window.attachedSheet != nil }
        let sheet = try XCTUnwrap(window.attachedSheet)
        let confirm = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: sheet.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        let suspended = expectation(description: "Deletion awaiting store")
        var release: CheckedContinuation<Void, Never>?
        defer { release?.resume() }
        context.store.onDelete = { _, _ in
            await withCheckedContinuation { release = $0; suspended.fulfill() }
        }
        XCTAssertTrue(sheet.performKeyEquivalent(with: confirm))
        await fulfillment(of: [suspended], timeout: 2)
        // A store change can remove the event before its own deletion finishes.
        // Once that drawer disappears, the user can start a new event.
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized) }
        await state.refreshCalendarAccessStatus()
        XCTAssertFalse(state.panel.isEventDetailPresented)
        state.panel.newEventInitialDate = day
        state.panel.isNewEventSheetPresented = true
        view.rootView = AnyView(NewEventSheet(appState: state, metrics: metrics))
        view.layoutSubtreeIfNeeded()
        let refreshed = expectation(description: "Deletion reload applied")
        state.events.onEventsSnapshotChanged = { refreshed.fulfill() }
        release?.resume()
        release = nil
        await fulfillment(of: [refreshed], timeout: 2)
        try await waitForLayout(window)
        XCTAssertTrue(state.panel.isNewEventSheetPresented, "An old deletion must not close a new draft")
        XCTAssertEqual(state.panel.newEventInitialDate, day)
    }

    /// Store assets use the shipping views and an isolated calendar store, never personal events.
    /// Run with Xcode's -testLanguage/-testRegion; scripts/capture-app-store.sh exports both locales.
    func testStoreListingScreenshots() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let isRussian = Bundle.equinox.preferredLocalizations.first == "ru"
        let language = isRussian ? "ru" : "en"
        func copy(_ russian: String, _ english: String) -> String { isRussian ? russian : english }
        let day = CalendarDate(year: 2026, monthIndex: 8, day: 29)
        let base = day.date(in: Calendar.equinoxGregorian(timeZone: .current))
        let calendarTitle = copy("Работа", "Work")
        func event(_ offset: Int, _ hour: Int, _ title: String, meeting: Bool = false) -> DayEvent {
            let start = base.addingTimeInterval(Double(offset * 24 + hour) * 3600)
            let end = start.addingTimeInterval(3600)
            let identifier = "store-demo-\(offset)-\(hour)"
            let meetingURL = meeting ? URL(string: "https://meet.google.com/abc-defg-hij") : nil
            return DayEvent(
                id: identifier, eventIdentifier: identifier, calendarItemIdentifier: identifier,
                title: title, location: meeting ? "Google Meet" : nil,
                notes: meeting ? copy("Обсудить идеи и планы на неделю.", "Discuss ideas and plans for the week.") : nil,
                url: meetingURL, startDate: start, endDate: end, slotStartDate: start, slotEndDate: end,
                isEventAllDay: false, isSlotAllDay: false, joinURL: meetingURL,
                calendarIdentifier: "work", calendarTitle: calendarTitle,
                calendarColorRed: 0.28, calendarColorGreen: 0.48, calendarColorBlue: 0.84,
                calendarColorAlpha: 1, isRecurring: false, allowsContentModifications: true,
                participationStatus: meeting ? .accepted : nil
            )
        }
        let meeting = event(0, 14, copy("Встреча команды", "Team meeting"), meeting: true)
        let events: [CalendarDate: [DayEvent]] = [
            day: [meeting, event(0, 16, copy("Планирование проекта", "Project planning"))],
            day.addingDays(1): [event(1, 10, copy("Утренний фокус", "Morning focus")),
                                event(1, 15, copy("Обсуждение дизайна", "Design review"), meeting: true)]
        ]
        let entries: [CalendarListEntry] = [.source(copy("Мои календари", "My calendars")),
            .calendar(SelectableCalendar(id: "work", title: calendarTitle,
                sourceTitle: copy("Мои календари", "My calendars"), isSelected: true,
                colorRed: 0.28, colorGreen: 0.48, colorBlue: 0.84, colorAlpha: 1,
                allowsContentModifications: true))]
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, events: events, calendarEntries: entries)
        }
        await context.finishInitialization()
        state.preferences.sizePreference = SizePreference.large.rawValue
        state.preferences.backgroundStyle = BackgroundStyle.solid.rawValue
        state.preferences.showLocation = true
        state.preferences.showWeeks = true
        state.preferences.hasSeenShortcutTip = true
        state.preferences.weekStartWeekday = 1
        state.preferences.agendaHeightRatio = 0.5
        state.selectDate(day)
        state.events.todayDate = day
        state.events.currentTime = base.addingTimeInterval(13 * 3600)
        state.panel.isPanelVisible = true
        let metrics = SizeMetrics.metrics(for: .large)
        XCTAssertTrue(state.events.hasCalendars)
        XCTAssertEqual(state.events.eventsByDate[day]?.count, 2)

        try await captureStoreScreenshot(MainPanelView(appState: state)
            .frame(width: metrics.panelWidth).fixedSize(horizontal: false, vertical: true),
            title: copy("Месяц и встречи\nпод рукой", "Your month.\nYour next meeting."),
            subtitle: copy("Календарь и ближайшие события — в строке меню Mac.",
                           "Your calendar and upcoming events, in the Mac menu bar."),
            scheme: .light, language: language, name: "01-calendar")

        state.panel.selectedEvent = meeting
        state.panel.isEventDetailPresented = true
        try await captureStoreScreenshot(MainPanelView(appState: state)
            .frame(width: metrics.panelWidth + metrics.sheetWidth).fixedSize(horizontal: false, vertical: true),
            title: copy("Все детали.\nОдна панель.", "Every detail.\nOne panel."),
            subtitle: copy("Время, место и ссылка на встречу рядом с календарём.",
                           "Time, location, and a meeting link beside your calendar."),
            scheme: .light, language: language, name: "02-event")
        state.dismissEventDrawer()
        try await captureStoreScreenshot(MainPanelView(appState: state)
            .frame(width: metrics.panelWidth).fixedSize(horizontal: false, vertical: true),
            title: copy("Светлая\nили тёмная", "Light.\nOr dark."),
            subtitle: copy("Выберите тему, фон и удобный размер панели.",
                           "Choose your theme, background, and preferred panel size."),
            scheme: .dark, language: language, name: "03-appearance")
        XCTAssertTrue(context.store.operations.isEmpty, "Capturing assets must not mutate calendar data")
    }

    private func captureStoreScreenshot<Content: View>(
        _ content: Content, title: String, subtitle: String,
        scheme: ColorScheme, language: String, name: String
    ) async throws {
        let dark = scheme == .dark
        let captionColor = dark ? Color.white : Color(red: 0.12, green: 0.16, blue: 0.22)
        let canvas = VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image("AppLogo", bundle: .equinox).resizable().frame(width: 36, height: 36)
                Text(verbatim: "Equinox Calendar").font(.system(size: 20, weight: .semibold))
                Spacer()
                Text(verbatim: "macOS").font(.system(size: 16, weight: .medium)).opacity(0.55)
            }
            .foregroundStyle(captionColor)
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 24) {
                    Text(verbatim: title).font(.system(size: 44, weight: .semibold)).tracking(-1.4)
                    Text(verbatim: subtitle).font(.system(size: 21)).lineSpacing(6).opacity(0.7)
                }
                .frame(width: 340, alignment: .leading)
                .foregroundStyle(captionColor)
                content
                    .clipShape(RoundedRectangle(cornerRadius: EquinoxDesign.panelCornerRadius))
                    .shadow(color: .black.opacity(dark ? 0.25 : 0.12), radius: 24, y: 12)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 64).padding(.vertical, 44)
        .frame(width: 1440, height: 900)
        .background(dark ? Color(red: 0.09, green: 0.12, blue: 0.17)
                         : Color(red: 0.93, green: 0.95, blue: 0.97))
        .environment(\.colorScheme, scheme)
        .transaction { $0.disablesAnimations = true }
        let view = NSHostingView(rootView: canvas)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = view
        defer { window.contentView = nil }
        view.frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        view.layoutSubtreeIfNeeded()
        try await waitForLayout(window)
        view.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(view.fittingSize.width, 1440)
        XCTAssertLessThanOrEqual(view.fittingSize.height, 900)
        let rendered = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rendered)
        // AppKit needs its native bitmap format for capture. Flatten alpha only after rendering.
        let rgb = try XCTUnwrap(CGContext(data: nil, width: 2880, height: 1800,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        rgb.setFillColor(CGColor(gray: dark ? 0.1 : 0.95, alpha: 1))
        rgb.fill(CGRect(x: 0, y: 0, width: 2880, height: 1800))
        rgb.draw(try XCTUnwrap(rendered.cgImage), in: CGRect(x: 0, y: 0, width: 2880, height: 1800))
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(rgb.makeImage()))
        var minimumBrightness: CGFloat = 1
        var maximumBrightness: CGFloat = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: bitmap.pixelsHigh / 64) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: bitmap.pixelsWide / 64) {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                minimumBrightness = min(minimumBrightness, brightness)
                maximumBrightness = max(maximumBrightness, brightness)
            }
        }
        XCTAssertGreaterThan(maximumBrightness - minimumBrightness, 0.3, "Blank or uniform screenshot: \(name)")
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertFalse(bitmap.hasAlpha)
        XCTAssertGreaterThan(png.count, 50_000, "A store screenshot must contain the rendered interface")
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "store-\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNewEventFormSubmitsTheEnteredDraftAndClosesOnSuccess() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let entries = ["personal", "work"].map { identifier in
            CalendarListEntry.calendar(SelectableCalendar(
                id: identifier, title: identifier, sourceTitle: "QA", isSelected: true,
                colorRed: 0.2, colorGreen: 0.5, colorBlue: 0.8, colorAlpha: 1,
                allowsContentModifications: true
            ))
        }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, calendarEntries: entries) }
        await context.finishInitialization()
        let state = context.appState
        let selectedDay = CalendarDate(year: 2026, monthIndex: 8, day: 14)
        state.panel.newEventInitialDate = selectedDay
        state.panel.isNewEventSheetPresented = true
        let metrics = SizeMetrics.metrics(for: .medium)
        let view = NSHostingView(rootView: NewEventSheet(appState: state, metrics: metrics))
        let window = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: metrics.sheetWidth, height: 750),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil); window.contentView = nil }
        window.makeKeyAndOrderFront(nil)
        try await waitForLayout(window)
        try await waitUntil("New event title receives focus") {
            (window.firstResponder as? NSTextView)?.isFieldEditor == true
        }
        let editor = try XCTUnwrap(window.firstResponder as? NSTextView)
        disableAutomaticTextServices(in: editor)
        XCTAssertTrue(editor.string.isEmpty)
        let confirm = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertFalse(window.performKeyEquivalent(with: confirm), "An empty title must disable Add")
        editor.insertText("  Audit event  ", replacementRange: NSRange(location: NSNotFound, length: 0))
        try await waitForLayout(window)

        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized) }
        await state.refreshCalendarAccessStatus()
        try await waitForLayout(window)
        XCTAssertFalse(window.performKeyEquivalent(with: confirm), "Losing writable calendars must disable Add")
        XCTAssertTrue(context.store.createdDrafts.isEmpty)
        XCTAssertTrue(state.panel.isNewEventSheetPresented)
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, calendarEntries: entries) }
        await state.refreshCalendarAccessStatus()
        try await waitForLayout(window)

        XCTAssertTrue(window.performKeyEquivalent(with: confirm))
        try await waitUntil("Successful save closes the event form") {
            !state.panel.isNewEventSheetPresented && context.store.createdDrafts.count == 1
        }
        let draft = try XCTUnwrap(context.store.createdDrafts.first)
        XCTAssertEqual(draft.title, "Audit event")
        XCTAssertEqual(draft.calendarIdentifier, "work", "Use the default writable calendar, not the first entry")
        XCTAssertEqual(CalendarDate(date: draft.startDate, calendar: state.calendar), selectedDay)
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 3600)
        XCTAssertFalse(draft.isAllDay)
        XCTAssertEqual(draft.location, "")
        XCTAssertNil(draft.url)
        XCTAssertNil(draft.notes)
        XCTAssertNil(draft.recurrence)
        XCTAssertNil(draft.alertOffset)
        XCTAssertNil(state.panel.newEventInitialDate)
        XCTAssertEqual(context.store.operations, ["create", "refetch"])
    }

    func testWritableCalendarFormAcrossSizesAndThemes() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let entries: [CalendarListEntry] = [.source("QA"), .calendar(SelectableCalendar(
            id: "work", title: "Рабочий календарь команды — Release planning and product development",
            sourceTitle: "QA", isSelected: true,
            colorRed: 0.2, colorGreen: 0.5, colorBlue: 0.8, colorAlpha: 1,
            allowsContentModifications: true
        ))]
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, calendarEntries: entries) }
        await context.finishInitialization()
        context.appState.panel.isNewEventSheetPresented = true
        for size in SizePreference.allCases {
            context.appState.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            for scheme in [ColorScheme.light, .dark] {
                try await check(MainPanelView(appState: context.appState)
                    .environment(\.colorScheme, scheme),
                    width: metrics.panelWidth + metrics.sheetWidth, height: 850, scheme: scheme,
                    name: "writable-form-\(size)-\(scheme)")
            }
        }
    }

    func testWritableCalendarReplacementWhileFormRemainsOpen() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        state.panel.isNewEventSheetPresented = true
        state.preferences.sizePreference = SizePreference.medium.rawValue
        let metrics = SizeMetrics.metrics(for: .medium)
        let width = metrics.panelWidth + metrics.sheetWidth
        let view = NSHostingView(rootView: MainPanelView(appState: state))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 850),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = view
        defer { window.contentView = nil }
        for identifiers in [["work"], ["work", "personal"], ["personal"], [], ["work"]] {
            let entries = identifiers.map { id in
                CalendarListEntry.calendar(SelectableCalendar(
                    id: id, title: id, sourceTitle: "QA", isSelected: true,
                    colorRed: 0.2, colorGreen: 0.5, colorBlue: 0.8, colorAlpha: 1,
                    allowsContentModifications: true
                ))
            }
            context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, calendarEntries: entries) }
            await state.events.syncFromCalendarStore()
            view.layoutSubtreeIfNeeded()
            try await waitForLayout(window)
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(state.panel.isNewEventSheetPresented)
            XCTAssertLessThanOrEqual(view.fittingSize.width, width + 1)
            XCTAssertLessThanOrEqual(view.fittingSize.height, 851)
        }
        // scripts/test.sh also rejects SwiftUI's invalid-picker-selection diagnostic.
    }

    func testDenseAgendaAndLongNotesFitTheEventDrawer() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let start = day.date(in: state.calendar).addingTimeInterval(9 * 3600)
        let detail = context.event(start: start, title: String(repeating: "Длинное название 👩🏽‍💻 — Planning. ", count: 80),
                                   notes: String(repeating: "Заметки 👩🏽‍💻 e\u{301} / Notes\n", count: 1500))
        let events = [detail] + (1..<1000).map { context.event(start: start.addingTimeInterval(Double($0))) }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: events]) }
        await context.finishInitialization()
        state.selectDate(day)
        let metrics = SizeMetrics.metrics(for: .small)
        state.preferences.sizePreference = SizePreference.small.rawValue
        try await check(MainPanelView(appState: state), width: metrics.panelWidth, height: 850,
                        scheme: .light, name: "dense-agenda-1000")
        state.panel.selectedEvent = detail
        state.panel.isEventDetailPresented = true
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            for scheme in [ColorScheme.light, .dark] {
                try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                                width: metrics.panelWidth + metrics.sheetWidth, height: 850,
                                scheme: scheme, name: "dense-long-notes-\(size)-\(scheme)")
                XCTAssertTrue(state.panel.isEventDetailPresented)
            }
        }
    }

    func testDeletionConfirmationFitsWithLongAndMultilineEventTitles() async throws {
        for message in ["Team meeting", String(repeating: "Обсуждение запуска — Planning meeting. ", count: 100),
                        Array(repeating: "A separate line in an imported event title", count: 80).joined(separator: "\n")] {
            for scheme in [ColorScheme.light, .dark] {
                try await check(ModalConfirmDialog(
                    title: EventDeletionConfirmation.title(isRecurring: true),
                    message: message,
                    confirmTitle: String(localized: "Delete", bundle: .equinox, comment: ""),
                    onConfirm: {}, onCancel: {}
                ).environment(\.colorScheme, scheme),
                    width: ModalDesign.confirmWidth, height: EquinoxDesign.panelDefaultHeight,
                    scheme: scheme, name: "delete-confirmation-\(message.count)-\(scheme)")
            }
        }
    }

    func testEventDrawerShortcutsRespectBusyValidationAndDatePickerStates() async throws {
        let metrics = SizeMetrics.metrics(for: .medium)
        let cases = [
            (name: "ready", saving: false, deleting: false, invalid: false, cancelEnabled: true, confirms: 1, cancels: 1),
            (name: "invalid", saving: false, deleting: false, invalid: true, cancelEnabled: true, confirms: 0, cancels: 1),
            (name: "saving", saving: true, deleting: false, invalid: false, cancelEnabled: true, confirms: 0, cancels: 0),
            (name: "deleting", saving: false, deleting: true, invalid: false, cancelEnabled: true, confirms: 0, cancels: 0),
            (name: "date picker", saving: false, deleting: false, invalid: false, cancelEnabled: false, confirms: 1, cancels: 0),
        ]
        for testCase in cases {
            var confirms = 0
            var cancels = 0
            let content = EventDrawerScaffold(
                title: "Audit drawer", metrics: metrics, confirmTitle: "Confirm audit",
                confirmDisabled: testCase.invalid, isConfirming: testCase.saving,
                isDestructiveInProgress: testCase.deleting, isCancelShortcutEnabled: testCase.cancelEnabled,
                onCancel: { cancels += 1 }, onConfirm: { confirms += 1 }
            ) { Text("Audit content") }
            let window = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: metrics.sheetWidth, height: 300),
                                      styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: content)
            defer { window.orderOut(nil); window.contentView = nil }
            window.makeKeyAndOrderFront(nil)
            try await waitForLayout(window)
            for (characters, keyCode) in [("\r", UInt16(36)), ("\u{1b}", UInt16(53))] {
                let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: window.windowNumber, context: nil,
                    characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
                _ = window.performKeyEquivalent(with: event)
            }
            XCTAssertEqual(confirms, testCase.confirms, "\(testCase.name): Return")
            XCTAssertEqual(cancels, testCase.cancels, "\(testCase.name): Escape")
        }
    }

    func testCalendarGridKeyboardNavigationAndEventCreation() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        state.selectDate(CalendarDate(year: 2024, monthIndex: 1, day: 29))
        let metrics = SizeMetrics.metrics(for: .medium)
        let window = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: metrics.panelWidth, height: 500),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: CalendarGridView(appState: state, metrics: metrics))
        defer { window.orderOut(nil); window.contentView = nil }
        window.makeKeyAndOrderFront(nil)
        try await waitForLayout(window)
        let steps: [(characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, expected: CalendarDate)] = [
            ("\u{f703}", 124, [], CalendarDate(year: 2024, monthIndex: 2, day: 1)),
            ("\u{f702}", 123, [], CalendarDate(year: 2024, monthIndex: 1, day: 29)),
            ("\u{f700}", 126, [], CalendarDate(year: 2024, monthIndex: 1, day: 22)),
            ("\u{f701}", 125, [], CalendarDate(year: 2024, monthIndex: 1, day: 29)),
            ("\u{f703}", 124, [.option], CalendarDate(year: 2024, monthIndex: 2, day: 29)),
            ("\u{f702}", 123, [.option], CalendarDate(year: 2024, monthIndex: 1, day: 29)),
            ("\u{f703}", 124, [.option, .shift], CalendarDate(year: 2025, monthIndex: 1, day: 28)),
            ("\u{f702}", 123, [.option, .shift], CalendarDate(year: 2024, monthIndex: 1, day: 28)),
        ]
        for step in steps {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: step.modifiers.union(.function), timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: step.characters,
                charactersIgnoringModifiers: step.characters, isARepeat: false, keyCode: step.keyCode))
            window.sendEvent(event)
            try await waitForLayout(window)
            XCTAssertEqual(state.events.selectedDate, step.expected, "Key \(step.keyCode), modifiers \(step.modifiers)")
            XCTAssertEqual(state.events.monthDate.year, step.expected.year)
            XCTAssertEqual(state.events.monthDate.monthIndex, step.expected.monthIndex)
            XCTAssertFalse(state.panel.isNewEventSheetPresented)
        }
        let confirm = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        window.sendEvent(confirm)
        try await waitUntil("Return opens a draft for the selected grid day") { state.panel.isNewEventSheetPresented }
        XCTAssertEqual(state.panel.newEventInitialDate, CalendarDate(year: 2024, monthIndex: 1, day: 28))
    }

    func testDateCalendarKeyboardSelectionHonorsBothBoundsAndPreservesTime() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, hour: Int = 9, minute: Int = 30) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: minute)))
        }
        var selection = try date(11)
        var closes = 0
        let range = try date(10, hour: 0, minute: 0)...date(12, hour: 23, minute: 59)
        let metrics = SizeMetrics.metrics(for: .medium)
        let content = EventDateCalendar(selection: Binding(get: { selection }, set: { selection = $0 }),
                                        range: range, calendar: calendar, weekStartWeekday: 1,
                                        metrics: metrics, onClose: { closes += 1 })
        let window = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content)
        defer { window.orderOut(nil); window.contentView = nil }
        window.makeKeyAndOrderFront(nil)
        try await waitForLayout(window)
        let steps: [(characters: String, keyCode: UInt16, expectedDay: Int)] = [
            ("\u{f702}", 123, 10), ("\u{f702}", 123, 10),
            ("\u{f703}", 124, 11), ("\u{f703}", 124, 12), ("\u{f703}", 124, 12),
            ("\u{f700}", 126, 12), ("\u{f701}", 125, 12),
        ]
        for step in steps {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.function],
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                characters: step.characters, charactersIgnoringModifiers: step.characters,
                isARepeat: false, keyCode: step.keyCode))
            window.sendEvent(event)
            try await waitForLayout(window)
            XCTAssertEqual(selection, try date(step.expectedDay), "Arrow key \(step.keyCode) must preserve the time and stay inside the range")
            XCTAssertEqual(closes, 0)
        }
    }

    func testDateCalendarEscapeDoesNotReachDrawerCancel() async throws {
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let probe = DateCalendarEscapeProbe()
        let window = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
                                  styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: DateCalendarEscapeHarness(probe: probe))
        defer { window.orderOut(nil); window.contentView = nil }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        try await waitUntil("Date popover visible") {
            NSApp.windows.contains { $0 !== window && $0.isVisible && !existingWindows.contains(ObjectIdentifier($0)) }
        }
        let popover = try XCTUnwrap(NSApp.windows.first {
            $0 !== window && $0.isVisible && !existingWindows.contains(ObjectIdentifier($0))
        })
        let escape = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: popover.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false, keyCode: 53
        ))
        NSApp.sendEvent(escape)
        try await waitUntil("Calendar consumes Escape") { probe.calendarCloseCount == 1 && !popover.isVisible }
        XCTAssertEqual(probe.calendarCloseCount, 1)
        XCTAssertEqual(probe.drawerCloseCount, 0, "Escape must be consumed by the focused date calendar")
        XCTAssertFalse(popover.isVisible)
        XCTAssertTrue(window.isVisible)
        let drawerEscape = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false, keyCode: 53
        ))
        NSApp.sendEvent(drawerEscape)
        try await waitUntil("Drawer consumes second Escape") { probe.drawerCloseCount == 1 }
        XCTAssertEqual(probe.drawerCloseCount, 1, "The next Escape must reach the drawer")
    }

    func testPinnedPanelFollowsLateStatusItemMovesUntilManuallyMoved() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        state.isPinned = true
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let button = try XCTUnwrap(statusItem.button)
        let statusWindow = try XCTUnwrap(button.window)
        let originalStatusFrame = statusWindow.frame
        defer { statusWindow.setFrame(originalStatusFrame, display: false) }
        let statusScreen = try XCTUnwrap(statusWindow.screen)
        let screen = statusScreen.visibleFrame
        let statusY = statusScreen.frame.maxY - NSStatusBar.system.thickness
        let controller = PanelWindowController(appState: state)
        defer { controller.hide() }

        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            controller.show(statusItem: statusItem, isPinned: true)
            let window = try XCTUnwrap(controller.window)
            try await waitForLayout(window)
            XCTAssertEqual(window.level, .floating)
            XCTAssertTrue(window.isMovableByWindowBackground)

            // Reproduce menu bar layout continuing after the restored panel opens.
            for anchorX in [screen.midX - 80, screen.midX + 80] {
                statusWindow.setFrameOrigin(NSPoint(x: anchorX - button.frame.midX, y: statusY))
                controller.repositionUnderStatusItem(statusItem)
                let anchor = statusWindow.convertToScreen(button.frame)
                XCTAssertEqual(window.frame.midX, anchor.midX, accuracy: 1, "Pinned \(size) panel must follow the icon at login")
                XCTAssertLessThanOrEqual(window.frame.maxY, anchor.minY)
            }

            // AppKit posts willMove when a user starts dragging the floating panel.
            NotificationCenter.default.post(name: NSWindow.willMoveNotification, object: window)
            window.setFrameOrigin(NSPoint(x: screen.midX - window.frame.width / 2,
                                          y: screen.maxY - window.frame.height - 40))
            let manuallyPositioned = window.frame
            statusWindow.setFrameOrigin(NSPoint(x: screen.midX - 120 - button.frame.midX, y: statusY))
            controller.repositionUnderStatusItem(statusItem)
            XCTAssertEqual(window.frame.origin.x, manuallyPositioned.minX, accuracy: 1)
            XCTAssertEqual(window.frame.origin.y, manuallyPositioned.minY, accuracy: 1)

            state.isPinned = false
            controller.applyPinState(isPinned: false, statusItem: statusItem)
            XCTAssertEqual(window.level, .mainMenu)
            XCTAssertFalse(window.isMovableByWindowBackground)
            XCTAssertEqual(window.frame.midX, statusWindow.convertToScreen(button.frame).midX, accuracy: 1)
            state.isPinned = true
            controller.applyPinState(isPinned: true, statusItem: statusItem)
            controller.hide()
        }
    }

    func testStatusItemAppliesAppearanceAndSizeNotifications() async throws {
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let event = context.event(start: context.now)
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await context.finishInitialization()
        state.events.refreshTodayAndMeetingIndicator()
        XCTAssertTrue(state.events.shouldShowMeetingIndicator)
        state.isPinned = true
        state.preferences.isPinnedPanelVisible = false
        let controller = StatusItemController(appState: state)
        controller.setup()
        defer { controller.teardown() }
        state.onRequestPresentPanel?()
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? KeyablePanel }
            .first { !existingWindows.contains(ObjectIdentifier($0)) })
        defer { window.orderOut(nil) }
        try await waitForLayout(window)

        func statusButton(in view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton, (button.target as? StatusItemController) === controller {
                return button
            }
            return view.subviews.lazy.compactMap { statusButton(in: $0) }.first
        }
        let button = try XCTUnwrap(NSApp.windows.compactMap(\.contentView)
            .lazy.compactMap { statusButton(in: $0) }.first)
        let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        enum ExpectedIcon { case date, calendar, meeting, none }
        let cases: [(Bool, String?, Bool, ExpectedIcon, NSControl.ImagePosition)] = [
            (false, "HH:mm", true, .date, .imageLeading),
            (false, nil, false, .date, .imageOnly),
            (true, "HH:mm", false, .none, .noImage),
            (true, nil, false, .calendar, .imageOnly),
            (true, nil, true, .meeting, .imageOnly),
            (true, "HH:mm", true, .meeting, .imageLeading),
        ]
        for (hidden, clock, showsMeeting, kind, position) in cases {
            state.preferences.isIconHidden = hidden
            state.preferences.clockFormat = clock
            state.preferences.showMeetingIndicator = showsMeeting
            let expected: NSImage?
            switch kind {
            case .date:
                expected = try XCTUnwrap(MenuBarIconRenderer.iconImage(
                    text: MenuBarIconRenderer.iconText(prefs: state.preferences, calendar: state.calendar, today: day),
                    prefs: state.preferences, shouldShowMeetingIndicator: true, scale: scale))
            case .calendar:
                expected = try XCTUnwrap(MenuBarIconRenderer.hiddenDateFallbackImage(scale: scale))
            case .meeting:
                expected = try XCTUnwrap(MenuBarIconRenderer.meetingIndicatorImage(scale: scale))
            case .none:
                expected = nil
            }
            NotificationCenter.default.post(name: kEquinoxMenuBarAppearanceChanged, object: nil)
            try await waitUntil("Status item applies appearance notification: hidden=\(hidden), clock=\(clock ?? "none"), meeting=\(showsMeeting)") {
                button.title.isEmpty == (clock == nil)
                    && button.image?.tiffRepresentation == expected?.tiffRepresentation
            }
            // AppKit normalizes image-only placement when the title is empty.
            // With a clock title, the icon must precede it or be absent.
            if clock != nil { XCTAssertEqual(button.imagePosition, position) }
            if expected != nil { XCTAssertEqual(button.image?.isTemplate, true) }
        }

        let screen = try XCTUnwrap(button.window?.screen ?? NSScreen.main)
        for size in [SizePreference.small, .large, .medium] {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            let expectedAgendaLimit = PanelAgendaLayout.maxHeight(
                metrics: metrics, calendarRowCount: state.preferences.calendarRowCount,
                screenVisibleHeight: screen.visibleFrame.height)
            NotificationCenter.default.post(name: kEquinoxSizePreferenceChanged, object: nil)
            try await waitUntil("Status item applies size notification: \(size)") {
                abs(window.frame.width - metrics.panelWidth) <= 1
                    && state.layout.panelAgendaMaxHeight == expectedAgendaLimit
            }
        }
    }

    func testStatusItemReopensTodayWithoutOverridingDeepLinksOrDrafts() async throws {
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let controller = StatusItemController(appState: state)
        controller.setup()
        defer { controller.teardown() }
        let click = NSSelectorFromString("statusItemClicked")
        let today = state.events.todayDate
        let anotherDay = today.addingMonths(2)

        // These assertions concern synchronous presentation/navigation state.
        // Keep the sequence in one actor turn: waiting for unrelated layout lets
        // real desktop focus or mouse events dismiss this test's popover.
        for isPinned in [false, true] {
            state.isPinned = isPinned
            state.selectDate(anotherDay)
            let previousScrollToken = state.events.agendaScrollToken
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? KeyablePanel }
                .first { !existingWindows.contains(ObjectIdentifier($0)) })
            defer { window.orderOut(nil) }
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(state.events.selectedDate, today)
            XCTAssertEqual(state.events.monthDate, today)
            XCTAssertTrue(state.events.agendaFocusesDayStart)
            XCTAssertGreaterThan(state.events.agendaScrollToken, previousScrollToken)

            state.selectDate(anotherDay)
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(state.events.selectedDate, anotherDay, "Closing must not reset navigation")
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            XCTAssertEqual(state.events.selectedDate, today)
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))

            state.navigateToDate(anotherDay.date(in: state.calendar))
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(state.events.selectedDate, anotherDay, "Explicit date links must retain their destination")

            state.panel.newEventInitialDate = anotherDay
            state.panel.isNewEventSheetPresented = true
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            XCTAssertEqual(state.panel.newEventInitialDate, anotherDay)
            XCTAssertTrue(state.panel.isNewEventSheetPresented)
            XCTAssertEqual(state.events.selectedDate, anotherDay, "Returning to an unfinished draft must keep its context")
            XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
            state.dismissEventDrawer()
        }
    }

    func testStatusItemToggleHidesOpenDrawersInBothPanelModes() async throws {
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let event = context.event(start: day.date(in: state.calendar))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await context.finishInitialization()
        let controller = StatusItemController(appState: state)
        controller.setup()
        defer { controller.teardown() }
        let click = NSSelectorFromString("statusItemClicked")

        for isPinned in [false, true] {
            state.isPinned = isPinned
            for isCreating in [true, false] {
                state.panel.isNewEventSheetPresented = isCreating
                state.panel.newEventInitialDate = isCreating ? day : nil
                state.panel.isEventDetailPresented = !isCreating
                state.panel.selectedEvent = isCreating ? nil : event
                state.onRequestPresentPanel?()
                // Key-window activation is asynchronous and depends on desktop focus.
                // Identify this controller's panel without relying on the active app.
                let panels = NSApp.windows.compactMap { $0 as? KeyablePanel }
                    .filter { !existingWindows.contains(ObjectIdentifier($0)) }
                XCTAssertEqual(panels.count, 1)
                let window = try XCTUnwrap(panels.first)
                XCTAssertTrue(window.isVisible)
                defer { window.orderOut(nil) }

                for pinned in [!isPinned, isPinned] {
                    state.setPinned(pinned)
                    XCTAssertEqual(window.level, pinned ? .floating : .mainMenu)
                    XCTAssertEqual(window.isMovableByWindowBackground, pinned)
                    XCTAssertTrue(window.isVisible, "Changing pinning must preserve the open drawer")
                }

                XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
                XCTAssertFalse(window.isVisible, "The status item must hide an open drawer, including when pinned")
                XCTAssertFalse(state.panel.isPanelVisible)
                XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
                XCTAssertTrue(window.isVisible)
                XCTAssertTrue(state.panel.isPanelVisible)
                XCTAssertEqual(state.panel.isNewEventSheetPresented, isCreating)
                XCTAssertEqual(state.panel.selectedEvent?.id, isCreating ? nil : event.id)

                XCTAssertTrue(NSApp.sendAction(click, to: controller, from: nil))
                state.dismissEventDrawer()
            }
        }
    }

    func testEventDrawersAllowOutsideDismissalAndSurviveReopening() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let event = context.event(start: day.date(in: state.calendar))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await context.finishInitialization()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let controller = PanelWindowController(appState: state)
        defer { controller.hide() }
        controller.onDismissRequested = { [weak controller] in controller?.hide() }
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }

        for isCreating in [true, false] {
            state.panel.isNewEventSheetPresented = isCreating
            state.panel.newEventInitialDate = isCreating ? day : nil
            state.panel.isEventDetailPresented = !isCreating
            state.panel.selectedEvent = isCreating ? nil : event
            controller.show(statusItem: statusItem, isPinned: false)
            try await waitUntil("Panel visible") { controller.isVisible && controller.window?.contentView != nil }
            let window = try XCTUnwrap(controller.window)
            let content = try XCTUnwrap(window.contentView)
            XCTAssertFalse(controller.hasAttachedSheet, "An inline event drawer must not block hiding the panel")
            monitor.updateMonitoring(
                isPinned: false,
                isPanelVisible: true,
                isModalSheetPresented: { controller.hasAttachedSheet },
                isEquinoxWindow: { controller.isEquinoxCalendarWindow($0, statusItem: statusItem) },
                statusItemFrame: { nil },
                onOutsideClick: { controller.hide() }
            )

            monitor.handleMouseDown(window: window, screenLocation: .zero)
            XCTAssertTrue(controller.isVisible, "Interacting with the drawer must keep the panel open")
            monitor.handleMouseDown(window: nil, screenLocation: .zero)
            XCTAssertFalse(controller.isVisible)
            XCTAssertFalse(state.panel.isPanelVisible)
            monitor.teardown()

            controller.show(statusItem: statusItem, isPinned: false)
            try await waitUntil("Panel reopened") { controller.isVisible }
            XCTAssertTrue(controller.isVisible)
            XCTAssertTrue(window.contentView === content, "Reopening must retain the hosted form and its draft")
            XCTAssertEqual(state.panel.isNewEventSheetPresented, isCreating)
            XCTAssertEqual(state.panel.newEventInitialDate, isCreating ? day : nil)
            XCTAssertEqual(state.panel.isEventDetailPresented, !isCreating)
            XCTAssertEqual(state.panel.selectedEvent?.id, isCreating ? nil : event.id)
            window.cancelOperation(nil)
            XCTAssertTrue(controller.isVisible, "The window must leave Escape handling to the inline drawer")
            controller.hide()
            state.dismissEventDrawer()
        }
        controller.show(statusItem: statusItem, isPinned: false)
        let window = try XCTUnwrap(controller.window)
        XCTAssertTrue(controller.isVisible)
        window.cancelOperation(nil)
        XCTAssertFalse(controller.isVisible, "Escape dismisses the calendar when no drawer or sheet is open")
    }

    func testAttachedConfirmationSheetStillPreventsOutsideDismissal() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let controller = PanelWindowController(appState: context.appState)
        defer { controller.hide() }
        controller.onDismissRequested = { [weak controller] in controller?.hide() }
        controller.show(statusItem: statusItem, isPinned: false)
        let window = try XCTUnwrap(controller.window)
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        window.beginSheet(sheet, completionHandler: nil)
        defer {
            if window.attachedSheet === sheet { window.endSheet(sheet) }
            sheet.orderOut(nil)
        }
        XCTAssertTrue(controller.hasAttachedSheet)
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        monitor.updateMonitoring(
            isPinned: false,
            isPanelVisible: true,
            isModalSheetPresented: { controller.hasAttachedSheet },
            isEquinoxWindow: { controller.isEquinoxCalendarWindow($0, statusItem: statusItem) },
            statusItemFrame: { nil },
            onOutsideClick: { controller.hide() }
        )

        monitor.handleMouseDown(window: nil, screenLocation: .zero)

        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(context.appState.panel.isPanelVisible)
        window.cancelOperation(nil)
        XCTAssertTrue(controller.isVisible, "A native confirmation sheet must block calendar-window dismissal")
    }

    func testDrawerHeaderCloseKeepsCalendarOpenInBothPanelModes() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let state = context.appState
        let day = state.events.todayDate
        let event = context.event(start: day.date(in: state.calendar))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await context.finishInitialization()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let controller = PanelWindowController(appState: state)
        defer { controller.hide() }
        controller.onDismissRequested = { [weak controller] in controller?.hide() }

        for isPinned in [false, true] {
            state.isPinned = isPinned
            for size in SizePreference.allCases {
                state.preferences.sizePreference = size.rawValue
                let metrics = SizeMetrics.metrics(for: size)
                for isCreating in [false, true] {
                    state.panel.isNewEventSheetPresented = isCreating
                    state.panel.newEventInitialDate = isCreating ? day : nil
                    state.panel.isEventDetailPresented = !isCreating
                    state.panel.selectedEvent = isCreating ? nil : event
                    controller.show(statusItem: statusItem, isPinned: isPinned)
                    try await waitUntil("Drawer laid out") {
                        controller.window?.contentView?.layoutSubtreeIfNeeded()
                        return abs((controller.window?.frame.width ?? 0) - metrics.panelWidth - metrics.sheetWidth) <= 1
                    }
                    let window = try XCTUnwrap(controller.window)
                    try await waitForLayout(window)
                    let expanded = window.frame
                    let selectedDate = state.events.selectedDate
                    let point = NSPoint(
                        x: metrics.sheetWidth - EquinoxDesign.panelPadding - metrics.toolbarButtonSize / 2,
                        y: window.contentLayoutRect.height - EquinoxDesign.panelPadding - metrics.toolbarButtonSize / 2
                    )
                    let mouseUp = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                        eventNumber: 1, clickCount: 1, pressure: 0))
                    let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                        eventNumber: 0, clickCount: 1, pressure: 1))
                    NSApp.postEvent(mouseUp, atStart: true)
                    window.sendEvent(mouseDown)
                    try await waitUntil("Header closes drawer") {
                        !state.panel.isModalSheetPresented && abs(window.frame.width - metrics.panelWidth) <= 1
                    }

                    XCTAssertFalse(state.panel.isModalSheetPresented, "The header close button must dismiss only the drawer")
                    XCTAssertNil(state.panel.selectedEvent)
                    XCTAssertNil(state.panel.newEventInitialDate)
                    XCTAssertTrue(controller.isVisible)
                    XCTAssertTrue(state.panel.isPanelVisible)
                    XCTAssertEqual(state.events.selectedDate, selectedDate)
                    XCTAssertEqual(window.frame.width, metrics.panelWidth, accuracy: 1)
                    if isPinned {
                        XCTAssertEqual(window.frame.maxX, expanded.maxX, accuracy: 1)
                    }
                    controller.hide()
                }
            }
        }
    }

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
        controller.show(statusItem: statusItem, isPinned: true)
        let statusScreen = try XCTUnwrap(statusItem.button?.window?.screen ?? NSScreen.main)
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            controller.handleSizePreferenceChanged(statusItem: statusItem)
            XCTAssertEqual(state.layout.panelAgendaMaxHeight,
                           PanelAgendaLayout.maxHeight(metrics: metrics,
                                                       calendarRowCount: state.preferences.calendarRowCount,
                                                       screenVisibleHeight: statusScreen.visibleFrame.height),
                           "Changing size must update the agenda limit before resizing the already-open window")
            try await waitUntil("Calendar window resized") {
                controller.window?.contentView?.layoutSubtreeIfNeeded()
                return abs((controller.window?.frame.width ?? 0) - metrics.panelWidth) <= 1
            }
            let window = try XCTUnwrap(controller.window)
            try await waitForLayout(window)
            let heightWithAgenda = window.frame.height
            let allocatedAgendaHeight = AgendaLayout.agendaHeight(
                maxHeight: state.layout.panelAgendaMaxHeight,
                heightRatio: state.preferences.agendaHeightRatio
            ) + metrics.toolbarButtonSize
            state.preferences.showsAgenda = false
            try await waitUntil("Hiding agenda reduces the panel height") {
                window.frame.height < heightWithAgenda - 1
            }
            try await waitForLayout(window)
            XCTAssertEqual(heightWithAgenda - window.frame.height, allocatedAgendaHeight,
                           accuracy: 1, "Hiding agenda releases its content and toolbar space: \(size)")
            state.preferences.showsAgenda = true
            try await waitUntil("Showing agenda restores the panel height") {
                abs(window.frame.height - heightWithAgenda) <= 1
            }
            try await waitForLayout(window)
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
            defer { NotificationCenter.default.removeObserver(observer) }
            state.panel.isNewEventSheetPresented = true
            try await waitUntil("Drawer expanded") { abs(window.frame.width - metrics.panelWidth - metrics.sheetWidth) <= 1 }
            try await waitForLayout(window)
            let expanded = window.frame
            XCTAssertEqual(expanded.width, metrics.panelWidth + metrics.sheetWidth, accuracy: 1)
            XCTAssertEqual(expanded.height, collapsed.height, accuracy: 1, "The form must scroll within the calendar height")
            XCTAssertEqual(expanded.maxX, collapsed.maxX, accuracy: 1, "The drawer expands to the left")
            XCTAssertEqual(expanded.maxY, collapsed.maxY, accuracy: 1)
            XCTAssertNil(window.attachedSheet, "Creating an event must not cover the calendar with a sheet")
            state.dismissEventDrawer()
            try await waitUntil("Drawer collapsed") { abs(window.frame.width - metrics.panelWidth) <= 1 }
            try await waitForLayout(window)
            XCTAssertEqual(window.frame.width, metrics.panelWidth, accuracy: 1)
            XCTAssertEqual(window.frame.maxX, collapsed.maxX, accuracy: 1)
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
        let event = context.event(start: context.now, title: "Very long event title — Обсуждение запуска новой версии приложения и планов команды",
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
        let scenarios: [(String, CalendarStoreSnapshot, Bool)] = [
            ("not-determined", StubCalendarEventStore.snapshot(status: .notDetermined), false),
            ("denied", StubCalendarEventStore.snapshot(status: .denied), false),
            ("restricted", StubCalendarEventStore.snapshot(status: .restricted), false),
            ("loading", StubCalendarEventStore.snapshot(status: .authorized, hasCompletedInitialLoad: false), true),
            ("empty", StubCalendarEventStore.snapshot(status: .authorized, hasSelectedCalendars: false), false),
            ("loaded-empty", StubCalendarEventStore.snapshot(status: .authorized), true),
            ("initial-error", StubCalendarEventStore.snapshot(status: .authorized, hasCompletedInitialLoad: false,
                                                            lastFetchError: "Initial load failed"), false),
            ("error", StubCalendarEventStore.snapshot(status: .authorized, lastFetchError: "Unable to load calendars. Повторите попытку после восстановления доступа к календарям."), true)
        ]
        for (name, snapshot, showsAgenda) in scenarios {
            context.store.readSnapshot = { snapshot }
            await state.events.syncFromCalendarStore()
            state.events.shouldShowLoadingIndicator = name == "loading"
            for size in SizePreference.allCases {
                state.preferences.sizePreference = size.rawValue
                let metrics = SizeMetrics.metrics(for: size)
                let agendaHeight: CGFloat = 180
                let agenda = NSHostingView(rootView: AgendaView(appState: state, metrics: metrics, height: agendaHeight))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: metrics.panelWidth, height: 250),
                                      styleMask: [.borderless], backing: .buffered, defer: true)
                window.contentView = agenda
                defer { window.contentView = nil }
                agenda.layoutSubtreeIfNeeded()
                await Task.yield()
                agenda.layoutSubtreeIfNeeded()
                XCTAssertEqual(agenda.fittingSize.height, showsAgenda ? agendaHeight + metrics.toolbarButtonSize : 0,
                               accuracy: 1, "Agenda visibility and reserved height: \(name), \(size)")
                for scheme in [ColorScheme.light, .dark] {
                    try await check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                                    width: SizeMetrics.metrics(for: size).panelWidth, height: 900, scheme: scheme,
                                    name: "state-\(name)-\(size)-\(scheme)")
                }
            }
        }
    }

    func testFirstAgendaPresentationKeepsDistantSelectionFetchBounded() async throws {
        for selected in [CalendarDate.minimumSupported,
                         CalendarDate(year: 2060, monthIndex: 5, day: 15),
                         CalendarDate.maximumSupported] {
            let context = try CalendarTestContext()
            defer { context.cleanUp() }
            await context.finishInitialization()
            let state = context.appState
            state.panel.isPanelVisible = true
            state.selectDate(selected)
            let metrics = SizeMetrics.metrics(for: .medium)
            let view = NSHostingView(rootView: AgendaView(appState: state, metrics: metrics, height: 280))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: metrics.panelWidth, height: 320),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            defer { window.orderOut(nil); window.contentView = nil }
            window.orderFront(nil)
            view.layoutSubtreeIfNeeded()
            try await waitUntil("Agenda range fetched") {
                !(context.store.fetchedRanges + context.store.refetchedRanges).isEmpty && !state.events.isFetchingEvents
            }

            let ranges = context.store.fetchedRanges + context.store.refetchedRanges
            XCTAssertFalse(ranges.isEmpty)
            for range in ranges {
                XCTAssertLessThanOrEqual(range.first, selected)
                XCTAssertGreaterThanOrEqual(range.last, selected)
                XCTAssertLessThan(range.last.compare(range.first), 200,
                                  "Opening an empty agenda must not fetch all years between today and \(selected)")
            }
            XCTAssertEqual(state.events.selectedDate, selected)
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
        events[today]?.append(context.event(start: context.now.addingTimeInterval(-300)))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await context.finishInitialization()
        state.panel.isPanelVisible = true
        state.goToNextMonth()
        let initialDay = state.events.selectedDate
        XCTAssertNotEqual(initialDay, today)

        let geometry = AgendaGeometryProbe()
        let metrics = SizeMetrics.metrics(for: .medium)
        let view = NSHostingView(rootView: AgendaView(appState: state, metrics: metrics, height: 280)
            .overlayPreferenceValue(AgendaSectionFramesKey.self) { frames in
                AgendaGeometryRecorder(frames: frames, probe: geometry).allowsHitTesting(false)
            })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: metrics.panelWidth, height: 320),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil); window.contentView = nil }
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        // Finish initial presentation before testing a separate Today transition.
        // Any frame can arrive while SwiftUI is still positioning the first target.
        try await waitUntil("Initial agenda header aligned and fetch completed") {
            view.layoutSubtreeIfNeeded()
            return !state.events.isFetchingEvents
                && (geometry.frames[initialDay].map { abs($0.minY) <= 1 } ?? false)
        }

        state.goToToday()
        do {
            try await waitUntil("Today header aligned") {
                view.layoutSubtreeIfNeeded()
                return geometry.frames[today].map { abs($0.minY) <= 1 } ?? false
            }
        } catch {
            let evidence = XCTAttachment(string: "Selected: \(state.events.selectedDate); fetching: \(state.events.isFetchingEvents); headers: \(geometry.frames)")
            evidence.name = "today-scroll-state"
            evidence.lifetime = .keepAlways
            add(evidence)
            throw error
        }
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

        // The first event must remain actionable below the pinned Today header.
        let rowCenterY = metrics.toolbarButtonSize + header.maxY + metrics.agendaRowMinHeight / 2
        let rowPoint = NSPoint(x: metrics.panelWidth / 3,
                              y: view.isFlipped ? rowCenterY : view.bounds.height - rowCenterY)
        let point = view.convert(rowPoint, to: nil)
        let mouseUp = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 0))
        let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.postEvent(mouseUp, atStart: true)
        window.sendEvent(mouseDown)
        try await waitUntil("Clicking the first Today event opens its details") { state.panel.isEventDetailPresented }
        XCTAssertEqual(state.panel.selectedEvent?.id, try XCTUnwrap(events[today]?.first).id)
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
        try await waitUntil("Initial agenda fetched") {
            context.store.fetchedRanges.contains { $0.first <= start && $0.last >= start } && !state.events.isFetchingEvents
        }
        let fetchesBeforeNavigation = context.store.fetchedRanges.count

        var frameDurations: [Double] = []
        for _ in 0..<24 {
            let began = Date.timeIntervalSinceReferenceDate
            state.goToNextMonth()
            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            frameDurations.append(Date.timeIntervalSinceReferenceDate - began)
            // Keep the burst in one actor turn. Wall-clock pauses make the number
            // of coalesced fetches depend on machine load rather than navigation.
        }
        let finalDay = start.addingMonthsPreservingDay(24)
        try await waitUntil("Final navigation range fetched") {
            context.store.fetchedRanges.contains { $0.first <= finalDay && $0.last >= finalDay } && !state.events.isFetchingEvents
        }
        XCTAssertEqual(state.events.selectedDate, start.addingMonthsPreservingDay(24))
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

    private func waitForLayout(_ window: NSWindow) async throws {
        let clock = ContinuousClock()
        var lastChange = clock.now
        var previous: [NSRect] = []
        try await waitUntil("Window and hosted content layout settled") {
            window.contentView?.layoutSubtreeIfNeeded()
            if let content = window.contentView { disableAutomaticTextServices(in: content) }
            if let editor = window.fieldEditor(false, for: nil) { disableAutomaticTextServices(in: editor) }
            window.displayIfNeeded()
            let frames = [window.frame, window.contentView?.frame ?? .zero,
                          NSRect(origin: .zero, size: window.contentView?.fittingSize ?? .zero)]
            if frames != previous {
                previous = frames
                lastChange = clock.now
            }
            return lastChange.duration(to: clock.now) >= .milliseconds(100)
        }
    }

    private func disableAutomaticTextServices(in view: NSView) {
        // Layout fixtures must not depend on the desktop spell checker or Data
        // Detectors. AppKit can otherwise block on those external services while
        // checking synthetic form text. Keep the production editor unchanged.
        if let editor = view as? NSTextView {
            if editor.enabledTextCheckingTypes != 0 { editor.enabledTextCheckingTypes = 0 }
            if editor.isAutomaticTextCompletionEnabled { editor.isAutomaticTextCompletionEnabled = false }
        }
        view.subviews.forEach { disableAutomaticTextServices(in: $0) }
    }

    private func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out: \(description)", file: file, line: line)
                throw SurfaceWaitError.timeout
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private enum SurfaceWaitError: Error { case timeout }

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
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }


}

@MainActor
private final class DateCalendarEscapeProbe {
    var calendarCloseCount = 0
    var drawerCloseCount = 0
}

private struct DateCalendarEscapeHarness: View {
    let probe: DateCalendarEscapeProbe
    @State private var isPresented = false

    var body: some View {
        EventDrawerScaffold(title: "New event", metrics: .metrics(for: .medium),
                            isCancelShortcutEnabled: !isPresented,
                            onCancel: { probe.drawerCloseCount += 1 }) {
            Button("Date") { isPresented = true }
                .popover(isPresented: $isPresented) {
                    EventDateCalendar(selection: .constant(Date(timeIntervalSince1970: 1_789_214_400)),
                                      range: EventDraftDefaults.supportedDateRange(calendar: .equinoxGregorian()),
                                      calendar: .equinoxGregorian(), weekStartWeekday: 1,
                                      metrics: .metrics(for: .medium),
                                      onClose: {
                                          probe.calendarCloseCount += 1
                                          isPresented = false
                                      })
                }
        }
        .task { isPresented = true }
    }
}

@MainActor
private final class AgendaGeometryProbe {
    var frames: [CalendarDate: CGRect] = [:]
}

private struct AgendaGeometryRecorder: NSViewRepresentable {
    let frames: [CalendarDate: CGRect]
    let probe: AgendaGeometryProbe

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        probe.frames = frames
    }
}

@MainActor
private final class WindowGeometryProbe {
    var maximumWidthMismatch: CGFloat = 0
}
