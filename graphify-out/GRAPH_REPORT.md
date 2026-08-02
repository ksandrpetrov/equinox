# Graph Report - equinox  (2026-08-01)

## Corpus Check
- 161 files · ~47,731 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1832 nodes · 3696 edges · 115 communities (94 shown, 21 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 291 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1f1a7608`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PlaudCoordinator
- Sendable
- EquinoxComponents.swift
- PreferencesStore
- CallbackHandler
- EventParticipationStatus
- PlaudOAuthError
- .parseCreatedAt
- EquinoxDesign
- CalendarNavigationCoordinator
- SwiftUI
- equinox
- CalendarDate
- .privacyContent
- EquinoxFormatters
- StatusItemController
- .addingDays
- AgendaScrollCoordinator
- PanelWindowController
- EventsCoordinator
- JoinURLDetectionTests
- DesignSystemComplianceTests
- LoadingIndicatorController
- EventFetchCache
- View
- Foundation
- AgendaFocusTests
- EventDraftDefaultsTests
- AccessKind
- .nativeURLString
- SizeMetrics
- .match
- .buildDayEvents
- .shouldShow
- AppState
- CalendarListEntry
- .rgbComponents
- EKEvent
- EventLayoutInput
- ModalSheetScaffold
- DayCellView
- .refresh
- EventRSVPBar
- .colorHex
- SettingsTab
- CalendarListItem
- CalendarSelectionService
- CalendarStore
- PanelDismissMonitor
- EventDetailView
- EventKit
- DayEventUniqueCalendarsTests
- .navigateToDate
- PanelPresentationState
- monthGridDates
- GenerationError
- AgendaView
- PeriodicRefreshScheduler
- AppDelegate
- NewEventSheet
- .syncFromCalendarStore
- XCTestCase
- CalendarStoreError
- SettingsWindowCloseObserver
- DayEvent
- CalendarListingTests
- .fetchEventsWithStartDate
- ExternalChangeDispatcher
- .agendaHeight
- DayEvent
- MeetingProvider
- .dayEvent
- PlaudSettingsTab
- MainPanelView
- GeneralSettingsTab
- renderAppIcon
- String
- .detectJoinURL
- .intValue
- CalendarGridView
- AppearanceSettingsTab
- LaunchAtLogin
- PanelStateOverlay
- .applyCreate
- FetchRangeRefreshReason
- URLOpener.swift
- EventStripeView
- CalendarGridView
- ThemePreference
- xcodebuild-local-settings.sh
- run.sh
- require-arm64.sh
- MenuBarIconStyle
- String
- 2. Метрики качества
- Bool
- .resolveNativeJoinURL
- .testInitializationAndMutationsPostExactNotificationCounts
- Hashable
- CalendarsSettingsTab
- WeekendHighlightPicker
- Int
- KeyablePanel
- NSObjectProtocol
- 4. Правила изменения кода
- Set
- NSPanel
- NSStatusItem
- NSWindow
- MainActor
- StaticString
- UInt
- EventsCoordinator

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 92 edges
2. `AppState` - 50 edges
3. `EventsCoordinator` - 47 edges
4. `PreferencesStore` - 42 edges
5. `StatusItemController` - 37 edges
6. `XCTest` - 32 edges
7. `equinox` - 32 edges
8. `CalendarStore` - 31 edges
9. `PanelWindowController` - 29 edges
10. `PlaudRecording` - 29 edges

## Surprising Connections (you probably didn't know these)
- `CalendarNavigationCoordinatorTests` --calls--> `CalendarNavigationCoordinator`  [INFERRED]
  equinoxTests/CalendarNavigationCoordinatorTests.swift → equinox/App/CalendarNavigationCoordinator.swift
- `AgendaFocusTests` --calls--> `CalendarDate`  [EXTRACTED]
  equinoxTests/AgendaFocusTests.swift → equinox/Core/CalendarDate.swift
- `CalendarStore` --calls--> `EventFetchCache`  [INFERRED]
  equinox/Services/EventKit/CalendarStore.swift → equinox/Services/EventKit/EventFetchCache.swift
- `PlaudService` --calls--> `PlaudLiveClient`  [INFERRED]
  equinox/Services/Plaud/PlaudService.swift → equinox/Services/Plaud/PlaudLiveClient.swift
- `StatusItemController` --calls--> `PanelDismissMonitor`  [INFERRED]
  equinox/UI/MenuBar/StatusItemController.swift → equinox/UI/MenuBar/PanelDismissMonitor.swift

## Import Cycles
- None detected.

## Communities (115 total, 21 thin omitted)

### Community 0 - "PlaudCoordinator"
Cohesion: 0.05
Nodes (49): Codable, PlaudCoordinator, Bool, Calendar, CalendarAccessStatus, Date, DayEvent, Never (+41 more)

### Community 1 - "Sendable"
Cohesion: 0.06
Nodes (39): PlaudEventMatching, PlaudMatchableEvent, PlaudMatchSource, auto, manual, PlaudRecording, RecordingClaim, ScoredEventCandidate (+31 more)

### Community 2 - "EquinoxComponents.swift"
Cohesion: 0.05
Nodes (51): EquinoxAccessibility, PanelAccessibilityModifier, SettingsControlAccessibilityModifier, SettingsLabeledToggle, Bool, Content, String, View (+43 more)

### Community 3 - "PreferencesStore"
Cohesion: 0.05
Nodes (25): CalendarSelectionService, Bool, EKCalendar, EKEventStore, Set, String, UserDefaults, CalendarSelectionStorage (+17 more)

### Community 4 - "CallbackHandler"
Cohesion: 0.20
Nodes (12): async, CallbackHandler, PlaudOAuthCallbackServer, Data, Int, Never, String, Task (+4 more)

### Community 5 - "EventParticipationStatus"
Cohesion: 0.21
Nodes (4): EventParticipationMapping, Bool, EventParticipationTests, Int

### Community 6 - "PlaudOAuthError"
Cohesion: 0.07
Nodes (31): KeychainStore, KeychainStoreError, saveFailed, Data, OSStatus, String, PlaudOAuthClient, Bool (+23 more)

### Community 7 - ".parseCreatedAt"
Cohesion: 0.23
Nodes (8): PlaudOAuthPKCE, Data, String, PlaudOAuthAuthorizationRequest, PlaudOAuthAuthorizationRequestFactory, String, URL, RandomBytesGenerator

### Community 8 - "EquinoxDesign"
Cohesion: 0.06
Nodes (35): Animation, AnyTransition, ButtonStyle, BackgroundStyle, glass, solid, ChipMetrics, ColorToken (+27 more)

### Community 9 - "CalendarNavigationCoordinator"
Cohesion: 0.12
Nodes (8): CalendarNavigationCoordinator, MonthNavigationDirection, backward, forward, Bool, Calendar, Void, CalendarNavigationCoordinatorTests

### Community 10 - "SwiftUI"
Cohesion: 0.10
Nodes (14): AppKit, KeyboardShortcuts.Name, EventParticipationStatus, Color, SelectableCalendar, Color, NSColor, EventDetailLayout (+6 more)

### Community 11 - "equinox"
Cohesion: 0.06
Nodes (13): equinox, AgendaLayout, CGFloat, Double, Bool, CalendarAccessStatus, AgendaLayoutTests, DayEventUniqueCalendarsTests (+5 more)

### Community 12 - "CalendarDate"
Cohesion: 0.17
Nodes (7): Comparable, CalendarDate, Bool, Calendar, Date, Int, CalendarDateTests

### Community 13 - ".privacyContent"
Cohesion: 0.13
Nodes (19): Control, SettingsDetailScaffold, SettingsDivider, SettingsFooter, SettingsRow, SettingsSearchFilter, SettingsSection, SettingsSegmentedPicker (+11 more)

### Community 14 - "EquinoxFormatters"
Cohesion: 0.28
Nodes (7): DateFormatter, EquinoxFormatters, Calendar, Date, String, Void, Locale

### Community 15 - "StatusItemController"
Cohesion: 0.14
Nodes (7): DispatchWorkItem, StatusItemController, Bool, Never, NSStatusItem, Task, Void

### Community 16 - ".addingDays"
Cohesion: 0.27
Nodes (3): AgendaDisplayRange, Bool, AgendaDisplayRangeTests

### Community 17 - "AgendaScrollCoordinator"
Cohesion: 0.21
Nodes (10): AnyObject, AgendaScrollContext, AgendaScrollCoordinator, AgendaScrollTarget, day, event, EventsCoordinator, Bool (+2 more)

### Community 18 - "PanelWindowController"
Cohesion: 0.18
Nodes (11): PanelWindowController, Bool, CGFloat, SizeMetrics, MainPanelView, NSHostingController, NSPanel, NSRect (+3 more)

### Community 19 - "EventsCoordinator"
Cohesion: 0.06
Nodes (29): CalendarNavigationCoordinator, CheckedContinuation, EventFetchCoordinator, PendingFetch, Bool, CalendarDate, Void, EventsCoordinator (+21 more)

### Community 21 - "DesignSystemComplianceTests"
Cohesion: 0.16
Nodes (6): DesignSystemComplianceTests, Bool, StaticString, String, UInt, URL

### Community 22 - "LoadingIndicatorController"
Cohesion: 0.23
Nodes (9): LoadingIndicatorController, Bool, Date, Never, Task, TimeInterval, Void, LoadingIndicatorControllerTests (+1 more)

### Community 23 - "EventFetchCache"
Cohesion: 0.23
Nodes (13): EventFetchCache, FetchPlan, Bool, Calendar, CalendarDate, Date, DayEvent, String (+5 more)

### Community 24 - "View"
Cohesion: 0.15
Nodes (22): EventDetailCalendarChip, EventDetailHeroHeader, EventDetailJoinButton, EventDetailMetadataCard, EventDetailMetadataRow, EventDetailMetadataRowModel, EventDetailNotesCard, EventDetailSecondaryActionButton (+14 more)

### Community 25 - "Foundation"
Cohesion: 0.07
Nodes (13): CoreGraphics, CryptoKit, PanelLayoutMetrics, CGFloat, AgendaFocus, TimeInterval, AgendaSections, EventFetchRange (+5 more)

### Community 26 - "AgendaFocusTests"
Cohesion: 0.18
Nodes (9): Date, DayEvent, String, AgendaFocusTests, Bool, Date, DayEvent, String (+1 more)

### Community 27 - "EventDraftDefaultsTests"
Cohesion: 0.14
Nodes (7): EventDraftDefaults, Calendar, Date, Int, TimeInterval, EventDraftDefaultsTests, Calendar

### Community 28 - "AccessKind"
Cohesion: 0.15
Nodes (12): EKAuthorizationStatus, AccessKind, denied, fullAccess, notDetermined, restricted, unknown, writeOnly (+4 more)

### Community 29 - ".nativeURLString"
Cohesion: 0.18
Nodes (5): JoinURLDetection, NativeJoinURL, String, URL, NativeJoinURLTests

### Community 30 - "SizeMetrics"
Cohesion: 0.27
Nodes (4): PanelAgendaLayout, CGFloat, Int, PanelAgendaLayoutTests

### Community 31 - ".match"
Cohesion: 0.18
Nodes (4): JoinURLPresentation, String, URL, MeetingProviderTests

### Community 32 - ".buildDayEvents"
Cohesion: 0.22
Nodes (7): DayEventBuilder, DayEventSource, Calendar, CGFloat, Date, DayEvent, ResolveNativeJoinURL

### Community 33 - ".shouldShow"
Cohesion: 0.18
Nodes (10): Bool, Calendar, Date, DayEvent, Int, MeetingIndicatorTests, Bool, Date (+2 more)

### Community 34 - "AppState"
Cohesion: 0.14
Nodes (8): EnvironmentKey, AppState, Calendar, Void, Sendable, AppStateEnvironmentKey, EnvironmentValues, PlaudCoordinator

### Community 35 - "CalendarListEntry"
Cohesion: 0.18
Nodes (11): CalendarListEntry, calendar, source, CalendarListEntryFiltering, SelectableCalendar, Bool, CGFloat, String (+3 more)

### Community 36 - ".rgbComponents"
Cohesion: 0.07
Nodes (21): EKCalendarType, CalendarListing, CalendarListItem, Bool, String, ColorHex, RGBA, CGColor (+13 more)

### Community 37 - "EKEvent"
Cohesion: 0.19
Nodes (9): CGColor, CGFloat, Date, DayEvent, URL, EKEvent, EventParticipationAccessor, EventParticipationStatus (+1 more)

### Community 38 - "EventLayoutInput"
Cohesion: 0.30
Nodes (10): EventDaySlot, EventLayoutInput, EventSortKey, layoutEventDaySlots(), precedesInDisplayOrder(), Bool, Calendar, Date (+2 more)

### Community 39 - "ModalSheetScaffold"
Cohesion: 0.18
Nodes (12): ModalBannerStyle, error, warning, ModalConfirmDialog, ModalErrorBanner, ModalSheetScaffold, Bool, CGFloat (+4 more)

### Community 40 - "DayCellView"
Cohesion: 0.13
Nodes (12): DayCellView, Bool, Calendar, CGFloat, Color, String, Void, AppearancePreview (+4 more)

### Community 41 - ".refresh"
Cohesion: 0.21
Nodes (5): URL, CalendarDate, Date, KeyPress, NSApplication

### Community 42 - "EventRSVPBar"
Cohesion: 0.22
Nodes (11): EventRSVPBar, EventRSVPBarLayout, compact, detail, standard, EventRSVPRespondBadge, Bool, Color (+3 more)

### Community 43 - ".colorHex"
Cohesion: 0.14
Nodes (9): PlaudOAuthCallbackParser, PlaudOAuthCallbackParseResult, authorizationCode, denied, invalid, missingCode, notFound, PlaudOAuthPKCETests (+1 more)

### Community 44 - "SettingsTab"
Cohesion: 0.23
Nodes (7): PanelDismissMonitor, Any, Bool, MainActor, NSObjectProtocol, NSWindow, Void

### Community 45 - "CalendarListItem"
Cohesion: 0.24
Nodes (6): PanelPresentationState, Bool, DayEvent, String, Void, PanelPresentationStateTests

### Community 46 - "CalendarSelectionService"
Cohesion: 0.20
Nodes (9): SettingsTab, about, appearance, calendars, general, plaud, privacy, shortcuts (+1 more)

### Community 47 - "CalendarStore"
Cohesion: 0.12
Nodes (12): AccessOperation, CalendarStore, Bool, Calendar, CalendarDate, CalendarListEntry, Date, DayEvent (+4 more)

### Community 48 - "PanelDismissMonitor"
Cohesion: 0.28
Nodes (10): ColorScheme, MenuBarIconRenderer, MenuBarIconView, MenuBarMeetingGlyph, Bool, Calendar, CGFloat, Color (+2 more)

### Community 49 - "EventDetailView"
Cohesion: 0.33
Nodes (4): EventDetailView, Bool, DayEvent, String

### Community 50 - "EventKit"
Cohesion: 0.33
Nodes (6): EventKitEventFields, Bool, Date, Int, String, URL

### Community 51 - "DayEventUniqueCalendarsTests"
Cohesion: 0.25
Nodes (5): Bool, DayEvent, Int, AgendaSectionsTests, DayEvent

### Community 52 - ".navigateToDate"
Cohesion: 0.22
Nodes (9): AgendaEventCard, AgendaSectionHeader, Bool, Calendar, Color, Date, DayEvent, String (+1 more)

### Community 53 - "PanelPresentationState"
Cohesion: 0.14
Nodes (14): 1. Назначение, 3. Перед началом работы, 5. Бизнес-сценарии, 6. UI/UX чеклист, 7. Тестирование, 8. Ревью и формат ответа, AGENTS.md — инструкция для AI-агентов и разработчиков, Edge cases (+6 more)

### Community 54 - "monthGridDates"
Cohesion: 0.31
Nodes (7): columnForWeekday(), monthGridBoundaryFlags(), monthGridDates(), Bool, Int, weekdayForColumn(), MonthGridTests

### Community 55 - "GenerationError"
Cohesion: 0.22
Nodes (8): GenerationError, failed, invalidCount, SecureRandomBytes, Data, Int, OSStatus, Error

### Community 56 - "AgendaView"
Cohesion: 0.14
Nodes (16): AgendaContentState, content, hidden, loading, AgendaSectionHeaderHeightKey, AgendaView, PendingDeleteEvent, CalendarDate (+8 more)

### Community 57 - "PeriodicRefreshScheduler"
Cohesion: 0.29
Nodes (4): PeriodicRefreshScheduler, TimeInterval, Void, Timer

### Community 58 - "AppDelegate"
Cohesion: 0.20
Nodes (8): SizeMetrics, SizePreference, large, medium, small, CGFloat, PanelCommandBar, String

### Community 59 - "NewEventSheet"
Cohesion: 0.22
Nodes (7): CalendarStoreError, calendarNotFound, endDateBeforeStart, eventNotFound, readOnlyCalendar, EventParticipationStatus, String

### Community 60 - ".syncFromCalendarStore"
Cohesion: 0.25
Nodes (7): DayEvent, Bool, CGFloat, Date, EventParticipationStatus, String, URL

### Community 61 - "XCTestCase"
Cohesion: 0.15
Nodes (6): CalendarDateParsing, String, CalendarDateParsingTests, EventFetchRangeTests, EventsCoordinatorSyncTests, XCTestCase

### Community 62 - "CalendarStoreError"
Cohesion: 0.17
Nodes (12): Swift (XCTest), Нотаризация и распространение, Первичная настройка, Подпись кода, Ресурсы Apple, Ручная сборка через xcodebuild, Сборка и запуск, Сборка и запуск GUI (+4 more)

### Community 63 - "SettingsWindowCloseObserver"
Cohesion: 0.15
Nodes (8): AppDelegate, Notification, SettingsActivationHandler, SettingsWindowCloseObserver, Notification, String, NSApplicationDelegate, NSObject

### Community 64 - "DayEvent"
Cohesion: 0.36
Nodes (4): DayEvent, DayEvent, Color, NSColor

### Community 65 - "CalendarListingTests"
Cohesion: 0.25
Nodes (7): CalendarAccessStatus, authorized, denied, notDetermined, restricted, Bool, String

### Community 67 - "ExternalChangeDispatcher"
Cohesion: 0.24
Nodes (7): CalendarParticipationError, eventNotFound, kvoFailed, notAnInvitation, ExternalChangeDispatcher, Sendable, Void

### Community 68 - ".agendaHeight"
Cohesion: 0.17
Nodes (12): equinox, Plaud (опционально), Архитектура, Быстрый старт, Документация, Календарь и панель, Лицензия, Настройки (+4 more)

### Community 69 - "DayEvent"
Cohesion: 0.29
Nodes (7): EventParticipationStatus, accepted, declined, pending, tentative, unknown, String

### Community 70 - "MeetingProvider"
Cohesion: 0.16
Nodes (9): JoinURLDetection, String, URL, MeetingProvider, MeetingProviderRegistry, Bool, String, URL (+1 more)

### Community 71 - ".dayEvent"
Cohesion: 0.33
Nodes (4): NewEventSheet, Bool, SelectableCalendar, String

### Community 72 - "PlaudSettingsTab"
Cohesion: 0.38
Nodes (3): PlaudSettingsTab, Bool, String

### Community 73 - "MainPanelView"
Cohesion: 0.33
Nodes (5): MainPanelView, Binding, Bool, CGFloat, ReferenceWritableKeyPath

### Community 74 - "GeneralSettingsTab"
Cohesion: 0.50
Nodes (3): GeneralSettingsTab, Bool, String

### Community 75 - "renderAppIcon"
Cohesion: 0.29
Nodes (6): NSBitmapImageRep, NSSize, renderAppIcon(), Int, URL, writePNG()

### Community 76 - "String"
Cohesion: 0.33
Nodes (6): Result, denied, exchangeFailed, listenFailed, success, timeout

### Community 77 - ".detectJoinURL"
Cohesion: 0.20
Nodes (10): Settings tabs, UI access patterns, Архитектура, Ключевые потоки, Обзор, Подсистема Plaud, Продуктовые поверхности, Слои (+2 more)

### Community 78 - ".intValue"
Cohesion: 0.40
Nodes (3): KeyboardShortcutMigration, Any, Int

### Community 79 - "CalendarGridView"
Cohesion: 0.50
Nodes (3): App, EquinoxApp, Scene

### Community 80 - "AppearanceSettingsTab"
Cohesion: 0.33
Nodes (5): AppearanceSettingsTab, Binding, Bool, Int, String

### Community 81 - "LaunchAtLogin"
Cohesion: 0.50
Nodes (3): LaunchAtLogin, Bool, ServiceManagement

### Community 82 - "PanelStateOverlay"
Cohesion: 0.40
Nodes (3): PanelStateOverlay, Bool, String

### Community 83 - ".applyCreate"
Cohesion: 0.40
Nodes (3): EKRecurrenceRule, EventKitMutation, EKCalendar

### Community 84 - "FetchRangeRefreshReason"
Cohesion: 0.40
Nodes (3): DayEvent, EventParticipationStatus, EventParticipationStatus

### Community 86 - "EventStripeView"
Cohesion: 0.50
Nodes (3): EventStripeView, CGFloat, Color

### Community 87 - "CalendarGridView"
Cohesion: 0.40
Nodes (4): CalendarGridView, Bool, Int, String

### Community 88 - "ThemePreference"
Cohesion: 0.40
Nodes (5): CaseIterable, ThemePreference, dark, light, system

### Community 93 - "MenuBarIconStyle"
Cohesion: 0.24
Nodes (7): MenuBarIconStyle, classic, compact, minimal, MenuBarIconPicker, Int, String

### Community 95 - "2. Метрики качества"
Cohesion: 0.29
Nodes (7): 2.1. Поддерживаемость, 2.2. Дешевизна при вайбкодинге, 2.3. Отсутствие мёртвого кода, 2.4. Стабильность продукта, 2.5. Стабильность бизнес-сценариев, 2.6. Стабильность UI/UX, 2. Метрики качества

### Community 97 - ".resolveNativeJoinURL"
Cohesion: 0.50
Nodes (3): NativeJoinURLResolver, NativeAppInstalledChecker, URL

### Community 98 - ".testInitializationAndMutationsPostExactNotificationCounts"
Cohesion: 0.14
Nodes (19): Equatable, PlaudMatchConfidence, high, NewEventDraft, RecurrenceDraft, RecurrenceFrequency, biweekly, daily (+11 more)

### Community 99 - "Hashable"
Cohesion: 0.67
Nodes (3): Field, title, Hashable

### Community 106 - "4. Правила изменения кода"
Cohesion: 0.67
Nodes (3): 4. Правила изменения кода, Слои, Состояние

## Knowledge Gaps
- **160 isolated node(s):** `visibleGrid`, `agendaBounds`, `eventNotFound`, `calendarNotFound`, `readOnlyCalendar` (+155 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Foundation` to `PlaudCoordinator`, `Sendable`, `PreferencesStore`, `EventParticipationStatus`, `PlaudOAuthError`, `.parseCreatedAt`, `EquinoxDesign`, `CalendarNavigationCoordinator`, `equinox`, `EquinoxFormatters`, `AgendaScrollCoordinator`, `EventsCoordinator`, `LoadingIndicatorController`, `EventDraftDefaultsTests`, `AccessKind`, `.nativeURLString`, `SizeMetrics`, `.match`, `.buildDayEvents`, `CalendarListEntry`, `.rgbComponents`, `EKEvent`, `EventLayoutInput`, `.colorHex`, `CalendarListItem`, `CalendarSelectionService`, `monthGridDates`, `GenerationError`, `PeriodicRefreshScheduler`, `.syncFromCalendarStore`, `XCTestCase`, `DayEvent`, `CalendarListingTests`, `ExternalChangeDispatcher`, `MeetingProvider`, `renderAppIcon`, `.intValue`, `.applyCreate`, `URLOpener.swift`, `.resolveNativeJoinURL`, `.testInitializationAndMutationsPostExactNotificationCounts`?**
  _High betweenness centrality (0.206) - this node is a cross-community bridge._
- **Why does `CalendarDate` connect `CalendarDate` to `PlaudCoordinator`, `.shouldShow`, `.testInitializationAndMutationsPostExactNotificationCounts`, `Hashable`, `DayCellView`, `CalendarNavigationCoordinator`, `CalendarListItem`, `.addingDays`, `AgendaScrollCoordinator`, `PanelDismissMonitor`, `DayEventUniqueCalendarsTests`, `.navigateToDate`, `monthGridDates`, `CalendarGridView`, `Foundation`, `AgendaFocusTests`, `EventDraftDefaultsTests`, `XCTestCase`?**
  _High betweenness centrality (0.180) - this node is a cross-community bridge._
- **Why does `AppState` connect `AppState` to `SwiftUI`, `.privacyContent`, `StatusItemController`, `PanelWindowController`, `EventsCoordinator`, `CalendarListEntry`, `.refresh`, `CalendarSelectionService`, `EventDetailView`, `AgendaView`, `AppDelegate`, `SettingsWindowCloseObserver`, `.dayEvent`, `MainPanelView`, `GeneralSettingsTab`, `PanelStateOverlay`, `FetchRangeRefreshReason`, `CalendarGridView`, `String`, `Bool`, `CalendarsSettingsTab`?**
  _High betweenness centrality (0.135) - this node is a cross-community bridge._
- **Are the 27 inferred relationships involving `CalendarDate` (e.g. with `.testInitialRangeAnchorsOnTodayWithPastAndFuture()` and `.testRangeCoveringExpandsPastAndFuture()`) actually correct?**
  _`CalendarDate` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `AppState` (e.g. with `.saveManualPlaudLink()` and `.errorBanner()`) actually correct?**
  _`AppState` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `visibleGrid`, `agendaBounds`, `eventNotFound` to the rest of the system?**
  _160 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `PlaudCoordinator` be split into smaller, more focused modules?**
  _Cohesion score 0.0509020618556701 - nodes in this community are weakly interconnected._