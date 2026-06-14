# Архитектура

## Обзор

equinox — это menu bar приложение, построенное как гибрид **AppKit-оболочки и SwiftUI-панелей**. Бизнес-логика живёт в `Core/`; доступ к EventKit ограничен двумя адаптерами:

```mermaid
flowchart TB
    subgraph gui [equinox.app]
        UI[UI/ SwiftUI views]
        AppState[AppState @MainActor]
        CalendarStore[CalendarStore actor]
    end
    subgraph cli [equinox-bridge]
        MCP[mcp/ TypeScript MCP]
        Bridge[EventKitBridge]
    end
    EK[(EventKit EKEventStore)]
    Core[Core/ pure logic]

    UI --> AppState
    AppState --> CalendarStore
    CalendarStore --> EK
    CalendarStore --> Core
    MCP --> Bridge
    Bridge --> EK
    Bridge --> Core
```

## Слои

| Слой | Путь | Ответственность |
|------|------|-----------------|
| App | `equinox/App/` | Жизненный цикл, `AppState`, константы, `registerDefaults()` |
| Core | `equinox/Core/` | Даты, сетка, лейаут, распознавание join URL, маппинг RSVP |
| Services | `equinox/Services/` | Шлюз к EventKit (`CalendarStore`), настройки, платформенные хелперы, **общий EventKit-маппинг** (`EventKitCalendarMapping` — app+bridge) |
| UI | `equinox/UI/` | SwiftUI-презентация; получает `AppState` + `SizeMetrics` |
| bridge | `bridge/` | Headless JSON CLI поверх EventKit |
| mcp | `mcp/` | MCP-инструменты, валидация Zod, аналитика расписания |

**Правило:** UI никогда не обращается к `EKEventStore` напрямую. MCP никогда не обращается к EventKit напрямую. Минимальная версия macOS — **26.0**; доступ к календарю использует только full-access API EventKit (`.fullAccess`, `requestFullAccessToEvents`).

## Состояние и уведомления

- `AppState` — `@Observable @MainActor`; composition root: `EventsCoordinator`, `PanelPresentationState`, `PanelLayoutMetrics`, `PlaudCoordinator`
- `PreferencesStore.shared` — персистентные настройки (`k*`-ключи в `Constants.swift`)
- `CalendarStore` — `actor`; единственный шлюз к EventKit в GUI
- Синхронизация событий: `EventsCoordinator.syncFromCalendarStore()` подтягивает снимки из `CalendarStore` после fetch/мутации/смены выбора календарей/выдачи доступа и внешних изменений EventKit (без NotificationCenter)
- Уведомления (только menu bar / appearance, не данные календаря):
  - `kEquinoxSizePreferenceChanged` — размер панели S/M/L
  - `kEquinoxMenuBarAppearanceChanged` — перерисовка иконки menu bar

## Различия поведения app и bridge

Задокументированные различия (намеренные; не выравнивать без явной задачи):

| Поведение | GUI (`CalendarStore`) | Bridge/MCP |
|-----------|----------------------|------------|
| Отклонённые приглашения | Показываются, dimmed в agenda | Отфильтрованы в `list_events`; `get_event` → `not_found` |
| Join URL | Web + переписывание на нативное приложение, если установлено | Только web URL (`JoinURLDetection`) |
| Многодневные события | Day-слоты `EventLayout` в сетке/agenda | Одно плоское событие на вхождение |
| Фильтр календарей | `CalendarSelectionStorage` + Настройки | Все календари, если не передан `calendarIds` |
| RSVP | `setParticipationStatus` в GUI (`EventRSVPBar`) | Команды нет |
| Редактирование события | Не поддерживается в GUI | `update_event` в MCP |
| TCC vocabulary | `CalendarAccessStatus.authorized` (legacy alias) | `full_access` / `write_only` в JSON bridge |
| `create_event` поля | recurrence, alarms, timezone (GUI-only) | title, dates, calendar, allDay, location, notes, url |
| `delete_event` span | Только `thisEvent` | `thisEvent` (default) или `futureEvents` |

## Ключевые потоки

**Создание события (GUI):** `NewEventSheet` → `NewEventDraft` → `AppState.createEvent` → `CalendarStore.createEvent` → EventKit

**Загрузка событий:** видимый диапазон сетки/agenda → `AppState.updateVisibleRange` → `CalendarStore.fetchEvents` → `EventsCoordinator.syncFromCalendarStore()` подтягивает снимки `DayEvent`

**RSVP (GUI):** `EventDetailView` → `EventRSVPBar` → `AppState.setParticipationStatus` → `EventsCoordinator` → `CalendarStore.setParticipationStatus` → EventKit (KVC `participationStatus`; только приглашения с участниками)

**Удаление события (GUI):** `EventDetailView` → `AppState.deleteEvent` → `CalendarStore.deleteEvent` (span: `thisEvent`)

**MCP list events:** инструмент → `invokeBridge({ command: "list_events", ... })` → `equinox-bridge` → EventKit

**Deep link:** `equinox://date/yyyy-MM-dd` → `AppDelegate.application(_:open:)` → `AppState` навигация на дату

## Подсистема Plaud

Интеграция с Plaud (записи встреч) — отдельная подсистема, не связанная с MCP/bridge.

```mermaid
flowchart TB
    UI[PlaudSettingsTab / EventDetailView]
    Coordinator[PlaudCoordinator @MainActor @Observable]
    Service[PlaudService actor]
    Live[PlaudLiveClient]
    Store[PlaudRecordingsStore]
    Cache[PlaudMatchCache]
    OAuth[PlaudOAuthClient]
    CoreMatch[Core/PlaudEventMatching]
    CorePKCE[Core/PlaudOAuthPKCE]

    UI --> Coordinator
    Coordinator --> Service
    Service --> Live
    Service --> Store
    Service --> Cache
    Service --> OAuth
    Service --> CoreMatch
    OAuth --> CorePKCE
```

- **Coordinator** — UI-facing состояние в `equinox/App/PlaudCoordinator.swift`: ссылки на события, refresh/history match, OAuth для settings
- **Service (actor)** — оркестрация match, cache, OAuth tokens, live API
- **Core** — чистая логика match (`PlaudEventMatching`), PKCE (`PlaudOAuthPKCE`), timestamp parsing (`PlaudTimestamp`)
- **Настройки:** вкладка Plaud (`PlaudSettingsTab`), флаг `kPlaudEnabled` в `PreferencesStore`
- **Privacy:** вкладка `PrivacySettingsTab` — статус TCC для app (и bridge через MCP settings)

## Settings tabs

General, Calendars, Appearance, **Privacy**, Shortcuts, About, MCP, **Plaud** — см. `SettingsTab` в `equinox/App/SettingsTab.swift`.

## Тесты

- `equinoxTests/` — unit-тесты Core и Services (без живого EventKit в unit-тестах)
- `mcp/test/` — разбор envelope bridge, аналитика
- Интеграционные/ручные — TCC, create/delete, выбор календарей

См. [AGENTS.md](AGENTS.md) §9 для матрицы «изменение → тест».
