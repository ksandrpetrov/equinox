import AppKit
import SwiftUI
import XCTest
@testable import EquinoxKit

@MainActor
final class SurfaceLayoutTests: XCTestCase {
    func testPanelAndEventSheetsLayoutAcrossSizesAndThemes() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let event = context.event(start: state.events.selectedDate.date(in: state.calendar))
        for size in SizePreference.allCases {
            state.preferences.sizePreference = size.rawValue
            let metrics = SizeMetrics.metrics(for: size)
            for scheme in [ColorScheme.light, .dark] {
                try check(MainPanelView(appState: state).environment(\.colorScheme, scheme),
                          width: metrics.panelWidth, height: 750, scheme: scheme, name: "panel-\(size)-\(scheme)")
                try check(NewEventSheet(appState: state, metrics: metrics).environment(\.colorScheme, scheme),
                          width: metrics.sheetWidth, height: 750, scheme: scheme, name: "create-\(size)-\(scheme)")
                try check(EventDetailView(appState: state, event: event, metrics: metrics).environment(\.colorScheme, scheme),
                          width: metrics.sheetWidth, height: 750, scheme: scheme, name: "details-\(size)-\(scheme)")
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
                try check(SettingsView(initialTab: tab)
                    .environment(\.appState, context.appState)
                    .environment(\.colorScheme, scheme),
                          width: 850, height: 700, scheme: scheme, name: "settings-\(tab)-\(scheme)")
                XCTAssertEqual(context.appState.panel.settingsInitialTab, tab)
            }
        }
    }

    private func check<Content: View>(_ content: Content, width: CGFloat, height: CGFloat, scheme: ColorScheme, name: String) throws {
        let view = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = view
        defer { window.contentView = nil }
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.fittingSize.width.isFinite)
        XCTAssertTrue(view.fittingSize.height.isFinite)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let attachment = XCTAttachment(data: try XCTUnwrap(bitmap.representation(using: .png, properties: [:])), uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
