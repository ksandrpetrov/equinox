# Graph Report - equinox  (2026-08-01)

## Corpus Check
- 233 files · ~71,130 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2436 nodes · 4997 edges · 149 communities (116 shown, 33 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 291 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e36bac97`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Plaud Event Matching
- Plaud Coordination
- Plaud OAuth Authentication
- Calendar Listing Mapping
- MCP Setup Configuration
- Event Synchronization Coordination
- Plaud TypeScript Cache
- Application Lifecycle State
- Plaud Timestamp Parsing
- Calendar List Filtering
- Swift Test Suite
- Design Tokens
- MCP Bridge Tool Registry
- App Bridge Server
- Bridge EventKit Main
- Calendar Navigation
- Calendar Access Status
- Calendar Store Fetching
- Plaud OAuth Callback
- MCP Bridge Invocation
- Menu Bar Panel Control
- EventKit Access Mapping
- MCP Output Schemas
- Panel Components Styling
- Calendar Date Arithmetic
- MCP Settings Coordination
- Pinned Panel Window
- MCP Package Configuration
- MCP Tool Error Handling
- Event Fetch Loading
- Event Fetch Cache
- Join URL Tests
- Agenda Scroll Coordination
- Agenda Focus Tests
- Bridge Date Parsing
- Design System Components
- App State Facade
- Preferences Persistence
- Event Draft Defaults
- Settings UI Components
- Schedule Analytics
- Native Meeting URLs
- Event Detail Components
- EventKit Bridge Commands
- Bridge Event Fixtures
- Design Compliance Tests
- Join URL Presentation
- MCP Bridge Validation
- Bridge Data Models
- Meeting Indicator
- Day Event Builder
- MCP TypeScript Compiler
- Bridge Response Data
- Application Constants Themes
- Menu Bar Icon Rendering
- App State Navigation
- Date Formatting
- Button Interaction Style
- MCP Architecture Documentation
- Event Layout
- Accessibility Components
- Modal Components
- Calendar Day Cell
- Bridge Protocol Documentation
- Calendar Date Tests
- Meeting Provider Detection
- Event RSVP Interface
- Architecture Documentation
- New Event Sheet
- Event Detail Actions
- Settings Tabs
- Agenda Display Range
- EventKit Event Mapping
- Agenda UI Components
- Panel Dismissal Monitoring
- Periodic Refresh Scheduler
- Bridge Event Mapping
- Bridge Command Validation
- Calendar Color Deduplication
- Product Documentation License
- MCP Date Validation
- Panel Presentation State
- Agenda Section Tests
- Month Grid Logic
- Agenda View
- Build TCC Documentation
- Calendar Store Errors
- Size Metrics Command Bar
- Agent Workflow Documentation
- Agenda Layout
- Event Calendar Colors
- MCP Tool Catalog
- Panel Agenda Layout
- MCP Server Prompts
- Day Event Model
- EventKit Mutations
- Plaud Settings UI
- App Bridge Contract Tests
- Design Asset Generator
- Preferences Tests
- Main Panel View
- Privacy Settings UI
- Keyboard Shortcut Migration
- Calendar Grid View
- Bridge Schema Sync Tests
- Quality Signing Rationale
- Launch at Login
- SettingsWindowCloseObserver
- Panel State Overlay
- URL Opening Service
- CalendarAccessStatus
- .requestAccess
- Keyable Panel
- General Settings UI
- Build Run Scripts
- Localization Workflow
- Bridge Command Names
- MCP Tool Names
- .applyBrowserHeaders
- MCP Embedding Script
- Xcode Local Settings
- Bridge Schema Generator
- MCP Name Generator
- ARM64 Requirement Script
- CalendarGridView
- EquinoxApp
- .generate
- EventStripeView
- KeyablePanel
- main.swift
- .accessStatus
- AgendaFocus
- EventFetchRange.swift
- PanelCommandBar
- PanelLayoutMetrics
- CalendarsSettingsTab
- BridgeEvent
- DateFormatter
- EKCalendar
- EKEventStore
- Set
- PlaudRecording
- Never
- Task
- EventParticipationStatus
- EventParticipationStatus
- EventParticipationStatus

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 113 edges
2. `PreferencesStore` - 51 edges
3. `AppState` - 42 edges
4. `EventsCoordinator` - 42 edges
5. `equinox` - 41 edges
6. `XCTest` - 39 edges
7. `McpConfigurator` - 38 edges
8. `StatusItemController` - 35 edges
9. `CalendarStore` - 33 edges
10. `PanelWindowController` - 29 edges

## Surprising Connections (you probably didn't know these)
- `MCP App Bridge Proxy` --semantically_similar_to--> `MCP to App Proxy to Bridge Path`  [INFERRED] [semantically similar]
  ARCHITECTURE.md → bridge/BRIDGE.md
- `Optional Plaud Integration` --semantically_similar_to--> `Plaud Subsystem`  [INFERRED] [semantically similar]
  README.md → ARCHITECTURE.md
- `Safe MCP Calendar Access Path` --semantically_similar_to--> `TCC-safe App Bridge Access Path`  [INFERRED] [semantically similar]
  README.md → BUILD.md
- `Optional Calendar MCP` --semantically_similar_to--> `Calendar MCP Server`  [INFERRED] [semantically similar]
  README.md → mcp/MCP.md
- `EventKit Access Boundary` --semantically_similar_to--> `UI and MCP Isolation from Direct EventKit Access`  [INFERRED] [semantically similar]
  AGENTS.md → ARCHITECTURE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **EventKit Access Flow** — architecture_appstate_composition_root, architecture_calendarstore_actor, architecture_mcp_app_bridge_proxy, architecture_eventkitbridge_adapter, architecture_mcp_list_events_flow [EXTRACTED 1.00]
- **Calendar MCP Surface Contract** — mcp_mcp_mcp_tools, mcp_mcp_zod_bridge_contract, mcp_mcp_mcp_prompts, mcp_mcp_mcp_resources [EXTRACTED 1.00]
- **Equinox Product Delivery Stack** — readme_equinox_product, readme_calendar_panel, readme_calendar_mcp, readme_plaud_integration [EXTRACTED 1.00]

## Communities (149 total, 33 thin omitted)

### Community 0 - "Plaud Event Matching"
Cohesion: 0.10
Nodes (27): EKRecurrenceRule, Equatable, PlaudEventMatch, PlaudMatchConfidence, high, PlaudMatchSource, auto, manual (+19 more)

### Community 1 - "Plaud Coordination"
Cohesion: 0.06
Nodes (40): PlaudCoordinator, Bool, Calendar, CalendarAccessStatus, Date, DayEvent, Never, PlaudEventMatch (+32 more)

### Community 2 - "Plaud OAuth Authentication"
Cohesion: 0.11
Nodes (21): PlaudOAuthClient, Bool, Data, String, TimeInterval, PlaudOAuthError, alreadySignedIn, authenticationDenied (+13 more)

### Community 3 - "Calendar Listing Mapping"
Cohesion: 0.06
Nodes (24): EKCalendar, CoreGraphics, EKCalendarType, CalendarListing, CalendarListItem, Bool, String, ColorHex (+16 more)

### Community 4 - "MCP Setup Configuration"
Cohesion: 0.10
Nodes (12): McpConfigurator, McpSetup, McpSetupError, claudeConfigurationFailed, invalidConfigFormat, notReady, Any, Bool (+4 more)

### Community 5 - "Event Synchronization Coordination"
Cohesion: 0.09
Nodes (11): EventsCoordinator, Bool, Calendar, CalendarAccessStatus, Date, DayEvent, EventParticipationStatus, Int (+3 more)

### Community 6 - "Plaud TypeScript Cache"
Cohesion: 0.09
Nodes (40): addLocalDays(), appleSecondsToDate(), attachPlaudRecordingsToEvents(), catalogStatus(), dateToAppleSeconds(), emptyMatchCache(), eventLookupKey(), isFiniteNumber() (+32 more)

### Community 7 - "Application Lifecycle State"
Cohesion: 0.09
Nodes (15): App, AppKit, EquinoxApp, KeyboardShortcuts.Name, EventParticipationStatus, Color, SelectableCalendar, Color (+7 more)

### Community 8 - "Plaud Timestamp Parsing"
Cohesion: 0.18
Nodes (6): PlaudTimestamp, Any, Date, String, TimeInterval, PlaudTimestampTests

### Community 9 - "Calendar List Filtering"
Cohesion: 0.20
Nodes (8): CalendarListEntry, EKCalendar, EKEventStore, CalendarSelectionService, Bool, String, UserDefaults, Set

### Community 11 - "Design Tokens"
Cohesion: 0.07
Nodes (33): Animation, AnyTransition, ButtonStyle, ChipMetrics, ColorToken, ControlWidth, EquinoxDesign, EventStripe (+25 more)

### Community 12 - "MCP Bridge Tool Registry"
Cohesion: 0.10
Nodes (22): BRIDGE_TOOL_COMMANDS, BridgeToolCommand, updateHasMutableField(), bridgeCalendarSchema, bridgeEventSchema, bridgeEventsDataSchema, bridgeParticipationStatusSchema, calendarsDataSchema (+14 more)

### Community 13 - "App Bridge Server"
Cohesion: 0.17
Nodes (13): HTTPBridgeRequest, HTTPBridgeRequestParser, HTTPBridgeRequestParseResult, complete, incomplete, invalid, HTTPBridgeResponseReason, McpAppBridgeRequestError (+5 more)

### Community 14 - "Bridge EventKit Main"
Cohesion: 0.10
Nodes (9): BridgeResponse, writeResponse(), AgendaFocus, TimeInterval, AgendaSections, AppBridgeEventContract, CalendarDateParsing, EventKit (+1 more)

### Community 15 - "Calendar Navigation"
Cohesion: 0.18
Nodes (8): CalendarNavigationCoordinator, MonthNavigationDirection, backward, forward, Bool, Calendar, Void, Calendar

### Community 16 - "Calendar Access Status"
Cohesion: 0.06
Nodes (30): CaseIterable, BackgroundStyle, glass, solid, ThemePreference, dark, light, system (+22 more)

### Community 17 - "Calendar Store Fetching"
Cohesion: 0.13
Nodes (11): Sendable, CalendarStore, ExternalChangeDispatcher, Bool, Calendar, EventParticipationStatus, NativeAppInstalledChecker, NSObjectProtocol (+3 more)

### Community 18 - "Plaud OAuth Callback"
Cohesion: 0.21
Nodes (10): async, CallbackHandler, Data, Int, NWConnection, NWListener, String, TimeInterval (+2 more)

### Community 19 - "MCP Bridge Invocation"
Cohesion: 0.12
Nodes (22): AppBridgeHttpError, AppBridgeState, appBridgeTimeoutMs(), BridgeInvocationError, BridgeNotFoundError, defaultAppBridgeStatePath, defaultBridgePath, execFileAsync (+14 more)

### Community 20 - "Menu Bar Panel Control"
Cohesion: 0.15
Nodes (7): DispatchWorkItem, StatusItemController, Bool, Never, NSStatusItem, Task, Void

### Community 21 - "EventKit Access Mapping"
Cohesion: 0.18
Nodes (13): EKAuthorizationStatus, AccessKind, denied, fullAccess, notDetermined, restricted, unknown, writeOnly (+5 more)

### Community 22 - "MCP Output Schemas"
Cohesion: 0.15
Nodes (23): eventsDataSchema, conflictGroupOutputSchema, dayScheduleStatsSchema, eventOutputSchema, findConflictsOutputSchema, findFreeTimeOutputSchema, freeTimeSlotOutputSchema, getEventBridgeDataSchema (+15 more)

### Community 23 - "Panel Components Styling"
Cohesion: 0.20
Nodes (12): Codable, NSLock, PlaudCachedMatch, PlaudCachedNegative, PlaudMatchCache, PlaudMatchCacheFile, Bool, Date (+4 more)

### Community 24 - "Calendar Date Arithmetic"
Cohesion: 0.15
Nodes (7): Comparable, CalendarDate, Bool, Date, Int, CalendarDateTests, EventFetchRangeTests

### Community 25 - "MCP Settings Coordination"
Cohesion: 0.17
Nodes (10): McpCoordinator, Bool, String, SettingsFooter, McpSettingsTab, Bool, String, ShortcutsSettingsTab (+2 more)

### Community 26 - "Pinned Panel Window"
Cohesion: 0.21
Nodes (9): BlockingBridgeInvoker, BridgeState, McpAppBridgeServerTests, Data, Int, Sendable, String, URL (+1 more)

### Community 27 - "MCP Package Configuration"
Cohesion: 0.08
Nodes (25): bin, equinox-mcp, dependencies, @modelcontextprotocol/sdk, zod, devDependencies, tsx, @types/node (+17 more)

### Community 28 - "MCP Tool Error Handling"
Cohesion: 0.18
Nodes (19): invokeBridge(), requireBridgeData(), getPlaudStatus(), accessRequestOutputSchema, accessStatusOutputSchema, plaudRecordingsOutputSchema, plaudStatusOutputSchema, bridgeInvocationHint() (+11 more)

### Community 29 - "Event Fetch Loading"
Cohesion: 0.23
Nodes (9): LoadingIndicatorController, Bool, Date, Never, Task, TimeInterval, Void, LoadingIndicatorControllerTests (+1 more)

### Community 30 - "Event Fetch Cache"
Cohesion: 0.18
Nodes (10): EventFetchCache, Bool, Calendar, Date, DayEvent, Set, String, EventFetchCacheTests (+2 more)

### Community 32 - "Agenda Scroll Coordination"
Cohesion: 0.17
Nodes (13): AnyObject, AgendaScrollContext, AgendaScrollCoordinator, AgendaScrollTarget, day, event, EventsCoordinator, Bool (+5 more)

### Community 33 - "Agenda Focus Tests"
Cohesion: 0.17
Nodes (9): Date, DayEvent, String, AgendaFocusTests, Bool, Date, DayEvent, String (+1 more)

### Community 34 - "Bridge Date Parsing"
Cohesion: 0.10
Nodes (16): CalendarAccessRequestResult, EventKitBridge, Bool, Data, String, BridgeCommand, BridgeEvent, BridgeResponse (+8 more)

### Community 35 - "Design System Components"
Cohesion: 0.05
Nodes (51): EquinoxAccessibility, PanelAccessibilityModifier, SettingsControlAccessibilityModifier, SettingsLabeledToggle, Bool, Content, String, View (+43 more)

### Community 37 - "Preferences Persistence"
Cohesion: 0.10
Nodes (14): PreferencesStore, Any, Bool, Double, Int, String, UserDefaults, Void (+6 more)

### Community 38 - "Event Draft Defaults"
Cohesion: 0.14
Nodes (7): EventDraftDefaults, Calendar, Date, Int, TimeInterval, EventDraftDefaultsTests, Calendar

### Community 39 - "Settings UI Components"
Cohesion: 0.14
Nodes (18): Control, SettingsDetailScaffold, SettingsDivider, SettingsRow, SettingsSearchFilter, SettingsSection, SettingsSegmentedPicker, SettingsSidebarLabel (+10 more)

### Community 40 - "Schedule Analytics"
Cohesion: 0.20
Nodes (20): analyzeSchedule(), BusyInterval, ConflictGroup, conflictGroupFromEntries(), dayKey(), dayKeyFormatter, DayScheduleStats, enumerateDays() (+12 more)

### Community 41 - "Native Meeting URLs"
Cohesion: 0.18
Nodes (5): JoinURLDetection, NativeJoinURL, String, URL, NativeJoinURLTests

### Community 42 - "Event Detail Components"
Cohesion: 0.16
Nodes (17): EventDetailCalendarChip, EventDetailHeroHeader, EventDetailJoinButton, EventDetailMetadataCard, EventDetailMetadataRow, EventDetailMetadataRowModel, EventDetailNotesCard, EventDetailSecondaryActionButton (+9 more)

### Community 44 - "Bridge Event Fixtures"
Cohesion: 0.11
Nodes (7): BridgeEventFieldKeys, Set, String, BridgeEventFixtures, BridgeEventFixturesTests, Set, String

### Community 45 - "Design Compliance Tests"
Cohesion: 0.16
Nodes (6): DesignSystemComplianceTests, Bool, String, URL, StaticString, UInt

### Community 46 - "Join URL Presentation"
Cohesion: 0.18
Nodes (4): JoinURLPresentation, String, URL, MeetingProviderTests

### Community 47 - "MCP Bridge Validation"
Cohesion: 0.15
Nodes (15): requireBridgeData(), AccessRequestData, AccessStatusData, BridgeCalendar, BridgeError, BridgeResponse, CalendarsData, EventData (+7 more)

### Community 48 - "Bridge Data Models"
Cohesion: 0.09
Nodes (33): AccessRequestData, AccessStatusData, AccessRequestData, AccessStatusData, BridgeCalendar, BridgeCommand, BridgeData, accessRequest (+25 more)

### Community 49 - "Meeting Indicator"
Cohesion: 0.16
Nodes (11): MeetingIndicator, Bool, Calendar, Date, DayEvent, Int, MeetingIndicatorTests, Bool (+3 more)

### Community 50 - "Day Event Builder"
Cohesion: 0.50
Nodes (3): NativeJoinURLResolver, NativeAppInstalledChecker, URL

### Community 51 - "MCP TypeScript Compiler"
Cohesion: 0.11
Nodes (17): compilerOptions, esModuleInterop, forceConsistentCasingInFileNames, lib, module, moduleResolution, outDir, resolveJsonModule (+9 more)

### Community 52 - "Bridge Response Data"
Cohesion: 0.19
Nodes (9): PanelWindowController, Bool, CGFloat, NSPanel, NSStatusItem, NSWindow, NSHostingController, NSRect (+1 more)

### Community 53 - "Application Constants Themes"
Cohesion: 0.25
Nodes (8): PlaudMatchableEvent, PlaudRecording, Date, PlaudEventMatchingTests, Calendar, Date, Int, TimeZone

### Community 54 - "Menu Bar Icon Rendering"
Cohesion: 0.15
Nodes (17): ColorScheme, MenuBarIconStyle, classic, compact, minimal, MenuBarIconRenderer, MenuBarIconView, MenuBarMeetingGlyph (+9 more)

### Community 55 - "App State Navigation"
Cohesion: 0.15
Nodes (6): AppState, Bool, Calendar, String, Void, EventsCoordinator

### Community 56 - "Date Formatting"
Cohesion: 0.28
Nodes (7): EquinoxFormatters, Calendar, Date, DateFormatter, String, Void, Locale

### Community 57 - "Button Interaction Style"
Cohesion: 0.23
Nodes (10): EKEvent, EventParticipationAccessor, EventParticipationStatus, Int, EventKitMutation, Bool, Date, EKCalendar (+2 more)

### Community 58 - "MCP Architecture Documentation"
Cohesion: 0.19
Nodes (15): MCP Plaud Cache Enrichment, Plaud Subsystem, No Retry after Potential Mutation Delivery, App Bridge and CLI Fallback Policy, Calendar MCP Server, Local Date and Inclusive End Date Semantics, Calendar MCP Reference, MCP Client and Environment Configuration (+7 more)

### Community 59 - "Event Layout"
Cohesion: 0.19
Nodes (15): EventDaySlot, EventLayoutInput, EventSortKey, layoutEventDaySlots(), precedesInDisplayOrder(), Bool, Calendar, Date (+7 more)

### Community 60 - "Accessibility Components"
Cohesion: 0.20
Nodes (5): CalendarSelectionStorage, String, UserDefaults, CalendarSelectionServiceTests, UserDefaults

### Community 61 - "Modal Components"
Cohesion: 0.18
Nodes (12): ModalBannerStyle, error, warning, ModalConfirmDialog, ModalErrorBanner, ModalSheetScaffold, Bool, CGFloat (+4 more)

### Community 62 - "Calendar Day Cell"
Cohesion: 0.25
Nodes (7): DayCellView, Bool, Calendar, CGFloat, Color, String, Void

### Community 63 - "Bridge Protocol Documentation"
Cohesion: 0.24
Nodes (12): MCP to App Proxy to Bridge Path, Equinox Bridge Protocol, Bridge Calendar Commands, Bridge Success and Error Envelope, BridgeEvent Data Shape, Declined Invitation Filtering, Equinox Bridge CLI, EventKit-only Bridge Scope (+4 more)

### Community 64 - "Calendar Date Tests"
Cohesion: 0.27
Nodes (4): String, CalendarDateParsingTests, EventsCoordinatorSyncTests, XCTestCase

### Community 65 - "Meeting Provider Detection"
Cohesion: 0.16
Nodes (9): JoinURLDetection, String, URL, MeetingProvider, MeetingProviderRegistry, Bool, String, URL (+1 more)

### Community 66 - "Event RSVP Interface"
Cohesion: 0.22
Nodes (11): EventParticipationStatus, EventRSVPBar, EventRSVPBarLayout, compact, detail, standard, EventRSVPRespondBadge, Bool (+3 more)

### Community 67 - "Architecture Documentation"
Cohesion: 0.19
Nodes (15): GUI and Bridge Behavior Matrix, AppKit Shell and SwiftUI Panels Hybrid, AppState Composition Root, Equinox Architecture, Hybrid Bridge Schema Code Generation, Calendar MCP Surface, CalendarStore Actor, Core Pure Logic Layer (+7 more)

### Community 68 - "New Event Sheet"
Cohesion: 0.07
Nodes (31): CalendarListEntry, calendar, source, CalendarListEntryFiltering, SelectableCalendar, Bool, CGFloat, String (+23 more)

### Community 69 - "Event Detail Actions"
Cohesion: 0.24
Nodes (7): EventDetailView, AppState, Bool, DayEvent, PlaudEventMatch, String, Task

### Community 70 - "Settings Tabs"
Cohesion: 0.13
Nodes (13): EnvironmentKey, SettingsTab, about, appearance, calendars, general, mcp, plaud (+5 more)

### Community 71 - "Agenda Display Range"
Cohesion: 0.15
Nodes (8): AgendaDisplayRange, Bool, Bool, DayEvent, Int, AgendaDisplayRangeTests, AgendaSectionsTests, DayEvent

### Community 72 - "EventKit Event Mapping"
Cohesion: 0.11
Nodes (16): BridgeEventMapping, BridgeEvent, DayEventSource, CGFloat, DayEventMapping, CGColor, CGFloat, Date (+8 more)

### Community 73 - "Agenda UI Components"
Cohesion: 0.50
Nodes (3): FetchRangeRefreshReason, agendaBounds, visibleGrid

### Community 74 - "Panel Dismissal Monitoring"
Cohesion: 0.22
Nodes (7): AppDelegate, AppState, Notification, URL, NSApplication, NSApplicationDelegate, StatusItemController

### Community 75 - "Periodic Refresh Scheduler"
Cohesion: 0.19
Nodes (10): PlaudEventMatching, RecordingClaim, ScoredEventCandidate, Calendar, Decoder, Double, Set, String (+2 more)

### Community 76 - "Bridge Event Mapping"
Cohesion: 0.27
Nodes (8): McpAppBridgeInvocationResult, failure, success, McpAppBridgeServer, NWListener, String, URL, NWEndpoint

### Community 77 - "Bridge Command Validation"
Cohesion: 0.18
Nodes (5): BridgeCommandValidation, Bool, Date, String, BridgeCommandValidationTests

### Community 78 - "Calendar Color Deduplication"
Cohesion: 0.26
Nodes (4): DayEventUniqueCalendarsTests, CGFloat, DayEvent, String

### Community 79 - "Product Documentation License"
Cohesion: 0.23
Nodes (12): License Document, MIT License, Software Provided Without Warranty, Optional Calendar MCP, Calendar Panel Experience, Equinox macOS Menu Bar Calendar, Existing Event Editing Reserved for MCP, macOS Platform Requirements (+4 more)

### Community 80 - "MCP Date Validation"
Cohesion: 0.41
Nodes (10): assertAnalyticsDateRange(), calendarDateSchema, calendarDayCount(), endDateAfterStartDate(), endDateOnOrAfterStartDate(), eventDateInputSchema, isValidCalendarDate(), optionalUrlSchema (+2 more)

### Community 81 - "Panel Presentation State"
Cohesion: 0.22
Nodes (6): PanelPresentationState, Bool, DayEvent, String, Void, PanelPresentationStateTests

### Community 82 - "Agenda Section Tests"
Cohesion: 0.20
Nodes (5): Date, NewEventSheet, Bool, SelectableCalendar, String

### Community 83 - "Month Grid Logic"
Cohesion: 0.31
Nodes (7): columnForWeekday(), monthGridBoundaryFlags(), monthGridDates(), Bool, Int, weekdayForColumn(), MonthGridTests

### Community 84 - "Agenda View"
Cohesion: 0.18
Nodes (11): AgendaEventCard, AgendaSectionHeader, Bool, Calendar, CalendarDate, Color, Date, DayEvent (+3 more)

### Community 85 - "Build TCC Documentation"
Cohesion: 0.24
Nodes (10): Independent App and Bridge TCC Permissions, TCC-safe App Bridge Access Path, Equinox Build and Run Guide, Bridge and MCP Build Pipeline, MCP Client Configuration, Manual Notarization Workflow, Apple Silicon macOS 26 Build Requirements, Release-only Local Run Workflow (+2 more)

### Community 86 - "Calendar Store Errors"
Cohesion: 0.05
Nodes (42): CalendarParticipationError, eventNotFound, kvoFailed, notAnInvitation, CalendarStoreError, calendarNotFound, endDateBeforeStart, eventNotFound (+34 more)

### Community 87 - "Size Metrics Command Bar"
Cohesion: 0.23
Nodes (6): PanelAgendaLayout, CGFloat, Int, SizeMetrics, CGFloat, PanelAgendaLayoutTests

### Community 88 - "Agent Workflow Documentation"
Cohesion: 0.28
Nodes (9): AGENTS.md Repository Instructions, Business Scenario Impact Review, Synchronous Dead Code Removal Policy, EventKit Access Boundary, Graphify Navigation and Update Workflow, Change-to-Test Matrix, AppState UI Access Pattern, UI and UX Regression Checklist (+1 more)

### Community 89 - "Agenda Layout"
Cohesion: 0.31
Nodes (4): AgendaLayout, CGFloat, Double, AgendaLayoutTests

### Community 90 - "Event Calendar Colors"
Cohesion: 0.31
Nodes (4): DayEvent, DayEvent, Color, NSColor

### Community 91 - "MCP Tool Catalog"
Cohesion: 0.23
Nodes (7): PanelDismissMonitor, Any, Bool, NSObjectProtocol, NSWindow, Void, MainActor

### Community 92 - "Panel Agenda Layout"
Cohesion: 0.31
Nodes (4): EventFetchCoordinator, Bool, Int, Void

### Community 93 - "MCP Server Prompts"
Cohesion: 0.36
Nodes (7): promptResult(), registerPrompts(), registerResources(), createEquinoxMcpServer(), require, runStdioServer(), { version }

### Community 94 - "Day Event Model"
Cohesion: 0.47
Nodes (3): Counts, NotificationCounter, Int

### Community 96 - "Plaud Settings UI"
Cohesion: 0.32
Nodes (3): PlaudSettingsTab, Bool, String

### Community 98 - "Design Asset Generator"
Cohesion: 0.29
Nodes (6): NSBitmapImageRep, NSSize, renderAppIcon(), Int, URL, writePNG()

### Community 99 - "Preferences Tests"
Cohesion: 0.50
Nodes (3): GeneralSettingsTab, Bool, String

### Community 100 - "Main Panel View"
Cohesion: 0.28
Nodes (7): MainPanelView, AppState, BackgroundStyle, Binding, Bool, CGFloat, ReferenceWritableKeyPath

### Community 101 - "Privacy Settings UI"
Cohesion: 0.35
Nodes (3): ProcessErrorOutput, Int, NWConnection

### Community 102 - "Keyboard Shortcut Migration"
Cohesion: 0.40
Nodes (3): KeyboardShortcutMigration, Any, Int

### Community 103 - "Calendar Grid View"
Cohesion: 0.25
Nodes (5): CryptoKit, PlaudOAuthPKCE, Data, String, RandomBytesGenerator

### Community 105 - "Quality Signing Rationale"
Cohesion: 0.40
Nodes (5): Change Quality Policy, Maintainability and Stability over Generation Speed, Signing Configuration Outside project.pbxproj, Local.xcconfig Signing Configuration, Keep Signing Data Outside the Repository

### Community 106 - "Launch at Login"
Cohesion: 0.50
Nodes (3): LaunchAtLogin, Bool, ServiceManagement

### Community 107 - "SettingsWindowCloseObserver"
Cohesion: 0.23
Nodes (7): SettingsActivationHandler, SettingsWindowCloseObserver, AppState, Notification, String, NSObject, SettingsTab

### Community 108 - "Panel State Overlay"
Cohesion: 0.33
Nodes (4): PanelStateOverlay, AppState, Bool, String

### Community 110 - "CalendarAccessStatus"
Cohesion: 0.24
Nodes (4): PeriodicRefreshScheduler, TimeInterval, Void, Timer

### Community 111 - ".requestAccess"
Cohesion: 0.22
Nodes (8): PlaudOAuthCallbackParser, PlaudOAuthCallbackParseResult, authorizationCode, denied, invalid, missingCode, notFound, Network

### Community 112 - "Keyable Panel"
Cohesion: 0.25
Nodes (7): DayEvent, Bool, CGFloat, Date, EventParticipationStatus, String, URL

### Community 113 - "General Settings UI"
Cohesion: 0.33
Nodes (5): AppearanceSettingsTab, Binding, Bool, Int, String

### Community 115 - "Localization Workflow"
Cohesion: 1.00
Nodes (3): Translation Catalog README, Application Translation Coverage, XLIFF Export and Import Workflow

### Community 118 - ".applyBrowserHeaders"
Cohesion: 0.40
Nodes (3): PlaudOAuthAuthorizationRequestFactory, PlaudOAuthConfiguration, URLRequest

### Community 126 - "CalendarGridView"
Cohesion: 0.24
Nodes (7): CalendarGridView, AppState, Bool, CalendarDate, Int, String, KeyPress

### Community 127 - "EquinoxApp"
Cohesion: 0.29
Nodes (7): PlaudOAuthCallbackServer, Result, denied, exchangeFailed, listenFailed, success, timeout

### Community 128 - ".generate"
Cohesion: 0.29
Nodes (6): AppearancePreview, Bool, Calendar, CalendarDate, Color, Int

### Community 129 - "EventStripeView"
Cohesion: 0.50
Nodes (3): EventStripeView, CGFloat, Color

### Community 130 - "KeyablePanel"
Cohesion: 0.50
Nodes (3): KeyablePanel, Bool, NSPanel

### Community 135 - "PanelCommandBar"
Cohesion: 0.50
Nodes (3): PanelCommandBar, AppState, String

## Knowledge Gaps
- **234 isolated node(s):** `CryptoKit`, `success`, `failure`, `incomplete`, `invalid` (+229 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **33 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Bridge EventKit Main` to `Plaud Event Matching`, `Plaud Coordination`, `Plaud OAuth Authentication`, `Calendar Listing Mapping`, `MCP Setup Configuration`, `EventFetchRange.swift`, `Application Lifecycle State`, `PanelLayoutMetrics`, `Plaud Timestamp Parsing`, `Swift Test Suite`, `App Bridge Server`, `Calendar Navigation`, `Calendar Access Status`, `Panel Components Styling`, `Event Fetch Loading`, `Event Fetch Cache`, `Agenda Scroll Coordination`, `Bridge Date Parsing`, `Event Draft Defaults`, `Native Meeting URLs`, `Join URL Presentation`, `Bridge Data Models`, `Meeting Indicator`, `Day Event Builder`, `Date Formatting`, `Event Layout`, `Accessibility Components`, `Meeting Provider Detection`, `New Event Sheet`, `Settings Tabs`, `Agenda Display Range`, `Agenda UI Components`, `Bridge Command Validation`, `Panel Presentation State`, `Month Grid Logic`, `Calendar Store Errors`, `Size Metrics Command Bar`, `Agenda Layout`, `Event Calendar Colors`, `Panel Agenda Layout`, `Design Asset Generator`, `Keyboard Shortcut Migration`, `Calendar Grid View`, `URL Opening Service`, `CalendarAccessStatus`, `.requestAccess`, `Keyable Panel`, `.applyBrowserHeaders`?**
  _High betweenness centrality (0.197) - this node is a cross-community bridge._
- **Why does `CalendarDate` connect `Calendar Date Arithmetic` to `Plaud Event Matching`, `Plaud Coordination`, `Event Synchronization Coordination`, `EventFetchRange.swift`, `AgendaFocus`, `Bridge EventKit Main`, `Calendar Navigation`, `Calendar Store Fetching`, `Event Fetch Cache`, `Agenda Scroll Coordination`, `Agenda Focus Tests`, `Event Draft Defaults`, `Meeting Indicator`, `Menu Bar Icon Rendering`, `App State Navigation`, `Calendar Day Cell`, `Calendar Date Tests`, `Agenda Display Range`, `Agenda UI Components`, `Panel Presentation State`, `Agenda Section Tests`, `Month Grid Logic`, `Panel Agenda Layout`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `Application Lifecycle State` to `.generate`, `EventStripeView`, `PanelCommandBar`, `CalendarsSettingsTab`, `Swift Test Suite`, `Design Tokens`, `Calendar Access Status`, `Design System Components`, `Preferences Persistence`, `Settings UI Components`, `Event Detail Components`, `Menu Bar Icon Rendering`, `Modal Components`, `Calendar Day Cell`, `Event RSVP Interface`, `New Event Sheet`, `Settings Tabs`, `Agenda Section Tests`, `Agenda View`, `Event Calendar Colors`, `Plaud Settings UI`, `Preferences Tests`, `Main Panel View`, `SettingsWindowCloseObserver`, `Panel State Overlay`, `General Settings UI`, `CalendarGridView`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Are the 26 inferred relationships involving `CalendarDate` (e.g. with `.testInitialRangeAnchorsOnTodayWithPastAndFuture()` and `.testRangeCoveringExpandsPastAndFuture()`) actually correct?**
  _`CalendarDate` has 26 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `PreferencesStore` (e.g. with `.testInitializationAndMutationsPostExactNotificationCounts()` and `.testInitializerNormalizesAndWritesBackConstrainedValues()`) actually correct?**
  _`PreferencesStore` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `CryptoKit`, `success`, `failure` to the rest of the system?**
  _234 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Plaud Event Matching` be split into smaller, more focused modules?**
  _Cohesion score 0.0967741935483871 - nodes in this community are weakly interconnected._