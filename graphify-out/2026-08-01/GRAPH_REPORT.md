# Graph Report - equinox  (2026-08-01)

## Corpus Check
- 161 files · ~46,576 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1789 nodes · 3593 edges · 122 communities (97 shown, 25 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 268 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `68154018`
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
- EquinoxApp
- FetchRangeRefreshReason
- URLOpener.swift
- EventStripeView
- .accessStatus
- .validCalendars
- xcodebuild-local-settings.sh
- run.sh
- require-arm64.sh
- MenuBarIconStyle
- .exchangeCode
- 2. Метрики качества
- EquinoxBannerPresentation
- EKEvent
- .testInitializationAndMutationsPostExactNotificationCounts
- .resolveNativeJoinURL
- EquinoxButtonVariant
- EquinoxCardStyle
- SettingsView.swift
- KeyablePanel
- CalendarSelectionServiceTests
- 4. Правила изменения кода
- AgendaFocus
- EventFetchRange.swift
- .init
- EquinoxButtonSize
- .calendarEntries
- Notification
- EventParticipationStatus
- CalendarAccessStatus
- EventParticipationStatus
- NativeAppInstalledChecker
- NSObjectProtocol
- Any
- Double
- CalendarAccessStatus
- Color

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 113 edges
2. `AppState` - 50 edges
3. `PreferencesStore` - 45 edges
4. `EventsCoordinator` - 42 edges
5. `StatusItemController` - 35 edges
6. `CalendarStore` - 32 edges
7. `XCTest` - 32 edges
8. `equinox` - 32 edges
9. `PlaudRecording` - 29 edges
10. `PanelWindowController` - 29 edges

## Surprising Connections (you probably didn't know these)
- `CalendarNavigationCoordinatorTests` --calls--> `CalendarNavigationCoordinator`  [INFERRED]
  equinoxTests/CalendarNavigationCoordinatorTests.swift → equinox/App/CalendarNavigationCoordinator.swift
- `AgendaFocusTests` --calls--> `CalendarDate`  [EXTRACTED]
  equinoxTests/AgendaFocusTests.swift → equinox/Core/CalendarDate.swift
- `EnvironmentValues` --references--> `AppState`  [EXTRACTED]
  equinox/UI/Settings/SettingsView.swift → equinox/App/AppState.swift
- `AgendaView` --calls--> `AgendaScrollCoordinator`  [INFERRED]
  equinox/UI/Main/AgendaView.swift → equinox/App/AgendaScrollCoordinator.swift
- `EventFetchCoordinator` --calls--> `LoadingIndicatorController`  [INFERRED]
  equinox/App/EventFetchCoordinator.swift → equinox/App/LoadingIndicatorController.swift

## Import Cycles
- None detected.

## Communities (122 total, 25 thin omitted)

### Community 0 - "PlaudCoordinator"
Cohesion: 0.05
Nodes (47): Codable, PlaudCoordinator, Bool, Calendar, CalendarAccessStatus, Date, DayEvent, Never (+39 more)

### Community 1 - "Sendable"
Cohesion: 0.07
Nodes (43): Equatable, PlaudEventMatch, PlaudEventMatching, PlaudMatchableEvent, PlaudMatchConfidence, high, PlaudMatchSource, auto (+35 more)

### Community 2 - "EquinoxComponents.swift"
Cohesion: 0.18
Nodes (17): EquinoxBadge, EquinoxBanner, EquinoxBannerStyle, error, info, warning, EquinoxChip, EquinoxJoinButton (+9 more)

### Community 3 - "PreferencesStore"
Cohesion: 0.16
Nodes (7): Any, Double, PreferencesStore, Bool, Int, String, Void

### Community 4 - "CallbackHandler"
Cohesion: 0.07
Nodes (31): async, PlaudOAuthPKCE, Data, String, CallbackHandler, PlaudOAuthCallbackParser, PlaudOAuthCallbackParseResult, authorizationCode (+23 more)

### Community 5 - "EventParticipationStatus"
Cohesion: 0.09
Nodes (18): CalendarAccessStatus, authorized, denied, notDetermined, restricted, Bool, String, EventParticipationMapping (+10 more)

### Community 6 - "PlaudOAuthError"
Cohesion: 0.12
Nodes (16): PlaudOAuthError, alreadySignedIn, authenticationDenied, authenticationTimeout, callbackListenFailed, callbackPortInUse, credentialsMissing, secureRandomGenerationFailed (+8 more)

### Community 7 - ".parseCreatedAt"
Cohesion: 0.09
Nodes (18): PlaudTimestamp, Any, Date, String, TimeInterval, PlaudLiveClient, PlaudLiveClientError, authFailed (+10 more)

### Community 8 - "EquinoxDesign"
Cohesion: 0.11
Nodes (17): Animation, AnyTransition, ChipMetrics, ColorToken, ControlWidth, EquinoxDesign, EventStripe, MenuBarDesign (+9 more)

### Community 9 - "CalendarNavigationCoordinator"
Cohesion: 0.13
Nodes (8): CalendarNavigationCoordinator, MonthNavigationDirection, backward, forward, Bool, Calendar, Void, CalendarNavigationCoordinatorTests

### Community 10 - "SwiftUI"
Cohesion: 0.07
Nodes (19): App, AppKit, EquinoxApp, KeyboardShortcuts.Name, EventParticipationStatus, Color, SelectableCalendar, Color (+11 more)

### Community 11 - "equinox"
Cohesion: 0.05
Nodes (16): equinox, PanelPresentationState, Bool, DayEvent, String, Void, AgendaLayout, CGFloat (+8 more)

### Community 12 - "CalendarDate"
Cohesion: 0.14
Nodes (9): Comparable, CalendarDate, Bool, Calendar, Date, Int, CalendarDateTests, EventFetchRangeTests (+1 more)

### Community 13 - ".privacyContent"
Cohesion: 0.19
Nodes (15): Control, SettingsDetailScaffold, SettingsDivider, SettingsFooter, SettingsRow, SettingsSearchFilter, SettingsSection, SettingsSegmentedPicker (+7 more)

### Community 14 - "EquinoxFormatters"
Cohesion: 0.13
Nodes (16): DateFormatter, EquinoxFormatters, Calendar, Date, String, Void, AgendaEventCard, AgendaSectionHeader (+8 more)

### Community 15 - "StatusItemController"
Cohesion: 0.05
Nodes (27): DispatchWorkItem, PanelDismissMonitor, Any, Bool, NSObjectProtocol, NSWindow, Void, PanelWindowController (+19 more)

### Community 16 - ".addingDays"
Cohesion: 0.16
Nodes (8): AgendaDisplayRange, Bool, Bool, DayEvent, Int, AgendaDisplayRangeTests, AgendaSectionsTests, DayEvent

### Community 17 - "AgendaScrollCoordinator"
Cohesion: 0.21
Nodes (10): AnyObject, AgendaScrollContext, AgendaScrollCoordinator, AgendaScrollTarget, day, event, EventsCoordinator, Bool (+2 more)

### Community 18 - "PanelWindowController"
Cohesion: 0.19
Nodes (15): ButtonStyle, PanelButtonGroup, PanelButtonStyle, PanelIconButton, panelIconLabel(), PanelIconMenuButton, Bool, CGFloat (+7 more)

### Community 19 - "EventsCoordinator"
Cohesion: 0.10
Nodes (10): EventsCoordinator, Bool, Calendar, CalendarAccessStatus, Date, DayEvent, EventParticipationStatus, Int (+2 more)

### Community 21 - "DesignSystemComplianceTests"
Cohesion: 0.16
Nodes (6): DesignSystemComplianceTests, Bool, String, URL, StaticString, UInt

### Community 22 - "LoadingIndicatorController"
Cohesion: 0.23
Nodes (9): LoadingIndicatorController, Bool, Date, Never, Task, TimeInterval, Void, LoadingIndicatorControllerTests (+1 more)

### Community 23 - "EventFetchCache"
Cohesion: 0.18
Nodes (10): EventFetchCache, Bool, Calendar, Date, DayEvent, Set, String, EventFetchCacheTests (+2 more)

### Community 24 - "View"
Cohesion: 0.15
Nodes (22): EventDetailCalendarChip, EventDetailHeroHeader, EventDetailJoinButton, EventDetailMetadataCard, EventDetailMetadataRow, EventDetailMetadataRowModel, EventDetailNotesCard, EventDetailSecondaryActionButton (+14 more)

### Community 26 - "AgendaFocusTests"
Cohesion: 0.17
Nodes (9): Date, DayEvent, String, AgendaFocusTests, Bool, Date, DayEvent, String (+1 more)

### Community 27 - "EventDraftDefaultsTests"
Cohesion: 0.14
Nodes (7): EventDraftDefaults, Calendar, Date, Int, TimeInterval, EventDraftDefaultsTests, Calendar

### Community 28 - "AccessKind"
Cohesion: 0.11
Nodes (14): Color, EKAuthorizationStatus, AccessKind, denied, fullAccess, notDetermined, restricted, unknown (+6 more)

### Community 29 - ".nativeURLString"
Cohesion: 0.18
Nodes (5): JoinURLDetection, NativeJoinURL, String, URL, NativeJoinURLTests

### Community 30 - "SizeMetrics"
Cohesion: 0.13
Nodes (12): PanelAgendaLayout, CGFloat, Int, SizeMetrics, SizePreference, large, medium, small (+4 more)

### Community 31 - ".match"
Cohesion: 0.18
Nodes (4): JoinURLPresentation, String, URL, MeetingProviderTests

### Community 32 - ".buildDayEvents"
Cohesion: 0.22
Nodes (7): DayEventBuilder, DayEventSource, Calendar, CGFloat, Date, DayEvent, ResolveNativeJoinURL

### Community 33 - ".shouldShow"
Cohesion: 0.16
Nodes (11): MeetingIndicator, Bool, Calendar, Date, DayEvent, Int, MeetingIndicatorTests, Bool (+3 more)

### Community 34 - "AppState"
Cohesion: 0.13
Nodes (9): AppState, Bool, Calendar, NewEventDraft, String, Void, SelectableCalendar, EventsCoordinator (+1 more)

### Community 35 - "CalendarListEntry"
Cohesion: 0.18
Nodes (11): CalendarListEntry, calendar, source, CalendarListEntryFiltering, SelectableCalendar, Bool, CGFloat, String (+3 more)

### Community 36 - ".rgbComponents"
Cohesion: 0.11
Nodes (16): CalendarListItem, CoreGraphics, EKCalendarType, EKEventStore, ColorHex, RGBA, CGColor, CGFloat (+8 more)

### Community 37 - "EKEvent"
Cohesion: 0.22
Nodes (7): EKRecurrenceRule, NewEventDraft, EventKitMutation, EKCalendar, EKEvent, NewEventDraft, RecurrenceDraft

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
Cohesion: 0.33
Nodes (3): CalendarSelectionStorage, String, UserDefaults

### Community 42 - "EventRSVPBar"
Cohesion: 0.22
Nodes (11): EventRSVPBar, EventRSVPBarLayout, compact, detail, standard, EventRSVPRespondBadge, Bool, Color (+3 more)

### Community 44 - "SettingsTab"
Cohesion: 0.18
Nodes (10): SettingsTab, about, appearance, calendars, general, plaud, privacy, shortcuts (+2 more)

### Community 45 - "CalendarListItem"
Cohesion: 0.20
Nodes (7): CalendarListing, CalendarListItem, Bool, String, SelectableCalendar, Bool, EKCalendar

### Community 46 - "CalendarSelectionService"
Cohesion: 0.31
Nodes (5): CalendarSelectionService, Bool, Set, String, UserDefaults

### Community 47 - "CalendarStore"
Cohesion: 0.15
Nodes (9): CalendarStore, Bool, Calendar, CalendarDate, Date, DayEvent, String, NativeAppInstalledChecker (+1 more)

### Community 48 - "PanelDismissMonitor"
Cohesion: 0.28
Nodes (10): ColorScheme, MenuBarIconRenderer, MenuBarIconView, MenuBarMeetingGlyph, Bool, Calendar, CGFloat, Color (+2 more)

### Community 49 - "EventDetailView"
Cohesion: 0.20
Nodes (6): DayEvent, EventDetailView, Bool, DayEvent, EventParticipationStatus, String

### Community 50 - "EventKit"
Cohesion: 0.15
Nodes (5): CryptoKit, AgendaSections, PlaudOAuthAuthorizationRequestFactory, EventKit, Foundation

### Community 51 - "DayEventUniqueCalendarsTests"
Cohesion: 0.28
Nodes (7): EquinoxButtonStyle, EquinoxCardModifier, Bool, CGFloat, Configuration, Double, View

### Community 52 - ".navigateToDate"
Cohesion: 0.28
Nodes (4): URL, CalendarDate, Date, NSApplication

### Community 53 - "PanelPresentationState"
Cohesion: 0.14
Nodes (14): 1. Назначение, 3. Перед началом работы, 5. Бизнес-сценарии, 6. UI/UX чеклист, 7. Тестирование, 8. Ревью и формат ответа, AGENTS.md — инструкция для AI-агентов и разработчиков, Edge cases (+6 more)

### Community 54 - "monthGridDates"
Cohesion: 0.31
Nodes (7): columnForWeekday(), monthGridBoundaryFlags(), monthGridDates(), Bool, Int, weekdayForColumn(), MonthGridTests

### Community 55 - "GenerationError"
Cohesion: 0.11
Nodes (18): CalendarParticipationError, eventNotFound, kvoFailed, notAnInvitation, CalendarStoreError, calendarNotFound, endDateBeforeStart, eventNotFound (+10 more)

### Community 56 - "AgendaView"
Cohesion: 0.12
Nodes (16): DayEvent, Bool, CGFloat, Date, EventParticipationStatus, String, URL, AgendaSectionHeaderHeightKey (+8 more)

### Community 57 - "PeriodicRefreshScheduler"
Cohesion: 0.22
Nodes (3): PreferencesStoreTests, UserDefaults, Void

### Community 58 - "AppDelegate"
Cohesion: 0.33
Nodes (4): AppDelegate, Notification, NSApplicationDelegate, StatusItemController

### Community 59 - "NewEventSheet"
Cohesion: 0.25
Nodes (6): Field, title, NewEventSheet, Bool, SelectableCalendar, String

### Community 60 - ".syncFromCalendarStore"
Cohesion: 0.27
Nodes (8): EquinoxAccessibility, PanelAccessibilityModifier, SettingsControlAccessibilityModifier, SettingsLabeledToggle, Bool, Content, String, View

### Community 61 - "XCTestCase"
Cohesion: 0.21
Nodes (5): CalendarDateParsing, String, CalendarDateParsingTests, EventsCoordinatorSyncTests, XCTestCase

### Community 62 - "CalendarStoreError"
Cohesion: 0.17
Nodes (12): Swift (XCTest), Нотаризация и распространение, Первичная настройка, Подпись кода, Ресурсы Apple, Ручная сборка через xcodebuild, Сборка и запуск, Сборка и запуск GUI (+4 more)

### Community 63 - "SettingsWindowCloseObserver"
Cohesion: 0.33
Nodes (5): SettingsActivationHandler, SettingsWindowCloseObserver, Notification, String, NSObject

### Community 64 - "DayEvent"
Cohesion: 0.36
Nodes (4): DayEvent, DayEvent, Color, NSColor

### Community 66 - ".fetchEventsWithStartDate"
Cohesion: 0.31
Nodes (4): EventFetchCoordinator, Bool, Int, Void

### Community 67 - "ExternalChangeDispatcher"
Cohesion: 0.38
Nodes (4): Sendable, ExternalChangeDispatcher, Sendable, Void

### Community 68 - ".agendaHeight"
Cohesion: 0.17
Nodes (12): equinox, Plaud (опционально), Архитектура, Быстрый старт, Документация, Календарь и панель, Лицензия, Настройки (+4 more)

### Community 69 - "DayEvent"
Cohesion: 0.27
Nodes (7): KeychainStore, KeychainStoreError, saveFailed, Data, OSStatus, String, LocalizedError

### Community 70 - "MeetingProvider"
Cohesion: 0.16
Nodes (9): JoinURLDetection, String, URL, MeetingProvider, MeetingProviderRegistry, Bool, String, URL (+1 more)

### Community 71 - ".dayEvent"
Cohesion: 0.14
Nodes (13): DayEventMapping, CGColor, CGFloat, Date, DayEvent, URL, EventKitEventFields, Bool (+5 more)

### Community 72 - "PlaudSettingsTab"
Cohesion: 0.32
Nodes (3): PlaudSettingsTab, Bool, String

### Community 73 - "MainPanelView"
Cohesion: 0.33
Nodes (5): MainPanelView, Binding, Bool, CGFloat, ReferenceWritableKeyPath

### Community 74 - "GeneralSettingsTab"
Cohesion: 0.50
Nodes (3): GeneralSettingsTab, Bool, String

### Community 75 - "renderAppIcon"
Cohesion: 0.33
Nodes (5): NSBitmapImageRep, renderAppIcon(), Int, URL, writePNG()

### Community 76 - "String"
Cohesion: 0.35
Nodes (3): PlaudOAuthClient, Data, TimeInterval

### Community 77 - ".detectJoinURL"
Cohesion: 0.20
Nodes (10): Settings tabs, UI access patterns, Архитектура, Ключевые потоки, Обзор, Подсистема Plaud, Продуктовые поверхности, Слои (+2 more)

### Community 78 - ".intValue"
Cohesion: 0.40
Nodes (3): KeyboardShortcutMigration, Any, Int

### Community 79 - "CalendarGridView"
Cohesion: 0.29
Nodes (5): CalendarGridView, Bool, Int, String, KeyPress

### Community 80 - "AppearanceSettingsTab"
Cohesion: 0.33
Nodes (5): AppearanceSettingsTab, Binding, Bool, Int, String

### Community 81 - "LaunchAtLogin"
Cohesion: 0.50
Nodes (3): LaunchAtLogin, Bool, ServiceManagement

### Community 82 - "PanelStateOverlay"
Cohesion: 0.40
Nodes (3): PanelStateOverlay, Bool, String

### Community 83 - "EquinoxApp"
Cohesion: 0.22
Nodes (8): CaseIterable, BackgroundStyle, glass, solid, ThemePreference, dark, light, system

### Community 84 - "FetchRangeRefreshReason"
Cohesion: 0.50
Nodes (3): FetchRangeRefreshReason, agendaBounds, visibleGrid

### Community 86 - "EventStripeView"
Cohesion: 0.50
Nodes (3): EventStripeView, CGFloat, Color

### Community 93 - "MenuBarIconStyle"
Cohesion: 0.24
Nodes (7): MenuBarIconStyle, classic, compact, minimal, MenuBarIconPicker, Int, String

### Community 94 - ".exchangeCode"
Cohesion: 0.36
Nodes (4): Bool, String, PlaudOAuthConfiguration, URLRequest

### Community 95 - "2. Метрики качества"
Cohesion: 0.29
Nodes (7): 2.1. Поддерживаемость, 2.2. Дешевизна при вайбкодинге, 2.3. Отсутствие мёртвого кода, 2.4. Стабильность продукта, 2.5. Стабильность бизнес-сценариев, 2.6. Стабильность UI/UX, 2. Метрики качества

### Community 96 - "EquinoxBannerPresentation"
Cohesion: 0.29
Nodes (6): CardPresentationModifier, EquinoxBannerPresentation, card, filled, Content, ViewModifier

### Community 97 - "EKEvent"
Cohesion: 0.47
Nodes (4): EKEvent, EventParticipationAccessor, EventParticipationStatus, Int

### Community 98 - ".testInitializationAndMutationsPostExactNotificationCounts"
Cohesion: 0.47
Nodes (3): Counts, NotificationCounter, Int

### Community 99 - ".resolveNativeJoinURL"
Cohesion: 0.50
Nodes (3): NativeJoinURLResolver, NativeAppInstalledChecker, URL

### Community 100 - "EquinoxButtonVariant"
Cohesion: 0.40
Nodes (5): EquinoxButtonVariant, bordered, destructive, plain, prominent

### Community 101 - "EquinoxCardStyle"
Cohesion: 0.40
Nodes (5): EquinoxCardStyle, raised, row, secondary, subtle

### Community 103 - "SettingsView.swift"
Cohesion: 0.50
Nodes (3): EnvironmentKey, AppStateEnvironmentKey, EnvironmentValues

### Community 104 - "KeyablePanel"
Cohesion: 0.50
Nodes (3): KeyablePanel, Bool, NSPanel

### Community 106 - "4. Правила изменения кода"
Cohesion: 0.67
Nodes (3): 4. Правила изменения кода, Слои, Состояние

### Community 110 - "EquinoxButtonSize"
Cohesion: 0.67
Nodes (3): EquinoxButtonSize, regular, small

## Knowledge Gaps
- **157 isolated node(s):** `1. Назначение`, `2.1. Поддерживаемость`, `2.2. Дешевизна при вайбкодинге`, `2.3. Отсутствие мёртвого кода`, `2.4. Стабильность продукта` (+152 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CalendarDate` connect `CalendarDate` to `PlaudCoordinator`, `Sendable`, `CalendarNavigationCoordinator`, `equinox`, `EquinoxFormatters`, `.addingDays`, `AgendaScrollCoordinator`, `EventsCoordinator`, `EventFetchCache`, `AgendaFocusTests`, `EventDraftDefaultsTests`, `.shouldShow`, `DayCellView`, `PanelDismissMonitor`, `EventKit`, `monthGridDates`, `AgendaView`, `XCTestCase`, `.fetchEventsWithStartDate`, `CalendarGridView`, `FetchRangeRefreshReason`, `EventFetchRange.swift`?**
  _High betweenness centrality (0.251) - this node is a cross-community bridge._
- **Why does `Foundation` connect `EventKit` to `PlaudCoordinator`, `Sendable`, `CallbackHandler`, `EventParticipationStatus`, `PlaudOAuthError`, `.parseCreatedAt`, `CalendarNavigationCoordinator`, `SwiftUI`, `equinox`, `EquinoxFormatters`, `StatusItemController`, `AgendaScrollCoordinator`, `LoadingIndicatorController`, `EventFetchCache`, `Foundation`, `EventDraftDefaultsTests`, `.nativeURLString`, `SizeMetrics`, `.match`, `.shouldShow`, `CalendarListEntry`, `.rgbComponents`, `EventLayoutInput`, `.refresh`, `SettingsTab`, `CalendarListItem`, `monthGridDates`, `GenerationError`, `AgendaView`, `XCTestCase`, `DayEvent`, `.fetchEventsWithStartDate`, `DayEvent`, `MeetingProvider`, `renderAppIcon`, `.intValue`, `EquinoxApp`, `FetchRangeRefreshReason`, `URLOpener.swift`, `.resolveNativeJoinURL`, `AgendaFocus`, `EventFetchRange.swift`?**
  _High betweenness centrality (0.146) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `SwiftUI` to `EquinoxComponents.swift`, `EquinoxDesign`, `equinox`, `.privacyContent`, `EquinoxFormatters`, `PanelWindowController`, `View`, `AccessKind`, `SizeMetrics`, `CalendarListEntry`, `ModalSheetScaffold`, `DayCellView`, `EventRSVPBar`, `PanelDismissMonitor`, `AgendaView`, `NewEventSheet`, `.syncFromCalendarStore`, `SettingsWindowCloseObserver`, `PlaudSettingsTab`, `MainPanelView`, `GeneralSettingsTab`, `CalendarGridView`, `AppearanceSettingsTab`, `PanelStateOverlay`, `EventStripeView`, `MenuBarIconStyle`, `SettingsView.swift`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Are the 27 inferred relationships involving `CalendarDate` (e.g. with `.testInitialRangeAnchorsOnTodayWithPastAndFuture()` and `.testRangeCoveringExpandsPastAndFuture()`) actually correct?**
  _`CalendarDate` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `AppState` (e.g. with `.saveManualPlaudLink()` and `.errorBanner()`) actually correct?**
  _`AppState` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `PreferencesStore` (e.g. with `.testInitializationAndMutationsPostExactNotificationCounts()` and `.testInitializerNormalizesAndWritesBackConstrainedValues()`) actually correct?**
  _`PreferencesStore` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `1. Назначение`, `2.1. Поддерживаемость`, `2.2. Дешевизна при вайбкодинге` to the rest of the system?**
  _157 weakly-connected nodes found - possible documentation gaps or missing edges._