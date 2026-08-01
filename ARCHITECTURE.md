# Архитектура

## Обзор

equinox — это menu bar приложение, построенное как гибрид **AppKit-оболочки и SwiftUI-панелей**. Бизнес-логика живёт в `Core/`; единственный шлюз к EventKit — `CalendarStore`:

```mermaid
flowchart TB
    subgraph gui [equinox.app]
        UI[UI/ SwiftUI views]
        AppState[AppState @MainActor]
        CalendarStore[CalendarStore actor]
    end
    EK[(EventKit EKEventStore)]
    Core[Core/ pure logic]

    UI --> AppState
    AppState --> CalendarStore
    CalendarStore --> EK
    CalendarStore --> Core
```

## Продуктовые поверхности

| Поверхность | Пользовательские возможности |
|-------------|------------------------------|
| Menu bar panel | Месячная сетка, agenda, выбор дня, навигация по месяцам, Today, popover/pinned panel |
| Event sheets | Создание события с датой/временем, all-day, календарём, location, URL, notes, recurrence и alert; просмотр деталей; удаление writable событий; RSVP |
| Settings | General, Calendars, Appearance, Privacy, Shortcuts, Plaud, About |
| Menu bar icon | Дата/день недели/месяц/часы, скрытая иконка, meeting indicator |
| Plaud | OAuth, refresh локального каталога, auto-match прошедших встреч, manual link, Open in Plaud |

## Слои

| Слой | Путь | Ответственность |
|------|------|-----------------|
| App | `equinox/App/` | Жизненный цикл, `AppState`, `EventsCoordinator`, `PanelPresentationState`, `PlaudCoordinator`, константы, defaults |
| Core | `equinox/Core/` | Даты, сетка, лейаут, распознавание join URL, RSVP mapping, Plaud matching, Plaud PKCE/timestamp parsing |
| Services | `equinox/Services/` | Шлюз к EventKit (`CalendarStore`), настройки, Plaud service/cache/OAuth, платформенные хелперы и EventKit-маппинг |
| UI | `equinox/UI/` | SwiftUI-презентация; получает `AppState` + `SizeMetrics`; не ходит в EventKit напрямую |

**Правило:** UI никогда не обращается к `EKEventStore` напрямую. Минимальная версия macOS — **26.0**; доступ к календарю использует только full-access API EventKit (`.fullAccess`, `requestFullAccessToEvents`).

## Состояние и уведомления

- `AppState` — `@Observable @MainActor`; composition root: `EventsCoordinator`, `PanelPresentationState`, `PanelLayoutMetrics`, `PlaudCoordinator`
- `PreferencesStore.shared` — персистентные настройки (`k*`-ключи в `Constants.swift`)
- `CalendarStore` — `actor`; единственный шлюз к EventKit
- Синхронизация событий: `EventsCoordinator.syncFromCalendarStore()` подтягивает снимки из `CalendarStore` после fetch/мутации/смены выбора календарей/выдачи доступа и внешних изменений EventKit (без NotificationCenter)
- Уведомления (только menu bar / appearance, не данные календаря):
  - `kEquinoxSizePreferenceChanged` — размер панели S/M/L
  - `kEquinoxMenuBarAppearanceChanged` — перерисовка иконки menu bar

## UI access patterns

`AppState` — composition root. Паттерн доступа из SwiftUI:

| Действие | Куда обращаться |
|----------|----------------|
| Мутации: create/delete event, RSVP, calendar selection, navigate+present | `AppState` facade (`createEvent`, `deleteEvent`, `selectDate`, `goToToday`, …) |
| Чтение/биндинг: `monthDate`, `selectedDate`, `eventsByDate`, loading flags | `appState.events` (`EventsCoordinator`) |
| Pin/popover, panel chrome | `appState.panel` (`PanelPresentationState`) |
| Plaud status, recordings, match UI | `appState.plaud` (`PlaudCoordinator`) |
| Персистентные настройки | `appState.preferences` (`PreferencesStore.shared`) |

Навигация по датам/месяцам вынесена в `CalendarNavigationCoordinator`; `EventsCoordinator` делегирует и re-export'ит flat API (`monthDate`, `selectDate`, …) без изменения call sites.

## Ключевые потоки

**Создание события (GUI):** `NewEventSheet` → `NewEventDraft` → `AppState.createEvent` → `CalendarStore.createEvent` → EventKit

**Загрузка событий:** видимый диапазон сетки/agenda → `AppState.updateVisibleRange` → `CalendarStore.fetchEvents` → `EventsCoordinator.syncFromCalendarStore()` подтягивает снимки `DayEvent`

**RSVP (GUI):** `EventDetailView` → `EventRSVPBar` → `AppState.setParticipationStatus` → `EventsCoordinator` → `CalendarStore.setParticipationStatus` → EventKit (KVC `participationStatus`; только приглашения с участниками)

**Удаление события (GUI):** `EventDetailView` → `AppState.deleteEvent` → `CalendarStore.deleteEvent` (span: `thisEvent`)

**Deep link:** `equinox://date/yyyy-MM-dd` → `AppDelegate.application(_:open:)` → `AppState` навигация на дату

## Подсистема Plaud

Интеграция с Plaud (записи встреч) — отдельная подсистема GUI.

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
- **Хранилище:** локальные JSON-снимки каталога записей и match cache в Application Support; OAuth tokens — в Keychain
- **Privacy:** вкладка `PrivacySettingsTab` — статус Calendar TCC для приложения

## Settings tabs

General, Calendars, Appearance, **Privacy**, Shortcuts, **Plaud**, About — см. `SettingsTab` в `equinox/App/SettingsTab.swift`.

## Тесты

- `equinoxTests/` — unit-тесты Core и Services (без живого EventKit в unit-тестах)
- Интеграционные/ручные — TCC, create/delete, выбор календарей

См. [AGENTS.md](AGENTS.md) §7 для матрицы «изменение → тест».
