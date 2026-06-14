# AGENTS.md — инструкция для AI-агентов и разработчиков

## 1. Назначение документа

Этот файл — **обязательная инструкция** для любых AI-агентов и разработчиков, которые меняют репозиторий equinox.

Цель: любое изменение должно **повышать или хотя бы не ухудшать** поддерживаемость, стабильность продукта, бизнес-сценариев и UI/UX.

**Приоритет:** при конфликте между скоростью генерации кода и поддерживаемостью проекта — всегда выбирать поддерживаемость, стабильность и сохранение бизнес-сценариев.

Дополнительные справочники:
- [BUILD.md](BUILD.md) — сборка, запуск, MCP, подпись кода

---

## 2. Основные метрики качества

Каждое изменение оценивается по шести метрикам.

### 2.1. Поддерживаемость проекта

Код должен быть понятным, локализованным по слоям и расширяемым без знания всего репозитория.

**В equinox это значит:**
- Бизнес-логика дат/сетки/лейаута — в `equinox/Core/`, без AppKit/SwiftUI/EventKit
- Доступ к EventKit — только через `CalendarStore` (app) и `EventKitBridge` (CLI)
- UI — только в `equinox/UI/`, получает `AppState` и `SizeMetrics` явно

### 2.2. Дешевизна при вайбкодинге

Код удобен для AI-агентов: говорящие имена, простая структура, низкая связность, явные контракты.

**В equinox это значит:**
- Константы UserDefaults — `let k*` в `equinox/App/Constants.swift`
- MCP-инструменты — Zod-схемы на входе, JSON-ответ bridge на выходе
- Чистые функции в `Core/` с XCTest рядом в `equinoxTests/`

### 2.3. Отсутствие мёртвого кода

Запрещено оставлять неиспользуемые компоненты, функции, флаги, стили, ветки логики, неактуальные комментарии и временные обходы без явного срока жизни.

**В equinox это значит:**
- Удалять `k*`-ключи из `Constants.swift` вместе с миграциями и UI
- Удалять MCP tools, bridge-команды, settings tabs и entitlements синхронно
- Не оставлять asset colors в `Colors.xcassets`, если они больше не используются

### 2.4. Стабильность продукта

Изменения не должны ломать существующее поведение, производительность, обработку ошибок, логику состояний и интеграции.

**В equinox это значит:**
- `CalendarStore` — `actor`; не нарушать изоляцию EventKit
- `NotificationCenter`: `kEquinoxSizePreferenceChanged`, `kEquinoxMenuBarAppearanceChanged` — не ломать подписчиков (события календаря синхронизируются напрямую через `EventsCoordinator.syncFromCalendarStore()`, без NotificationCenter)
- Два независимых TCC-разрешения: `equinox.app` и `equinox-bridge`

### 2.5. Стабильность бизнес-сценариев

Перед изменением определить, какие пользовательские сценарии затрагиваются. Нельзя менять поведение сценария без описания последствий.

**См. раздел 7** — полный список сценариев equinox.

### 2.6. Стабильность UI/UX

UI не должен деградировать: адаптивность, loading/error/empty, доступность, тексты, отступы, визуальная иерархия.

**В equinox это значит:**
- Использовать `DesignTokens.swift`, `PanelComponents`, `SettingsComponents`
- Размеры S/M/L через `SizeMetrics` — не хардкодить пиксели в view
- Строки — `String(localized:comment:)`; есть `ru.lproj` и `_translations/`

---

## 3. Правила перед началом работы

Перед любым изменением агент **обязан**:

1. **Изучить ближайший контекст** — прочитать файл и его прямых соседей (импорты, вызовы, тесты)
2. **Найти существующие аналоги** — поиск по репозиторию перед созданием новой сущности
3. **Проверить архитектурные паттерны** — слои `App/`, `Core/`, `Services/`, `UI/`; не смешивать ответственности
4. **Понять бизнес-сценарии** — см. раздел 7
5. **Определить UI/UX-регрессии** — см. раздел 8
6. **Найти связанные тесты** — `equinoxTests/` для Swift Core, `mcp/test/` для MCP
7. **Проверить, нет ли уже реализации** — особенно в `Core/`, `Services/`, `mcp/src/tools/`
8. **Не создавать новый механизм**, если можно расширить существующий (`CalendarStore`, `PreferencesStore`, `DesignTokens`, bridge-команды)
9. **Зафиксировать предположения**, если данных недостаточно — в ответе агента (раздел 11)

### Карта «куда смотреть первым»

| Задача | Сначала изучить |
|--------|-----------------|
| Сетка/даты | `equinox/Core/MonthGrid.swift`, `equinox/Core/CalendarDate.swift`, `equinoxTests/MonthGridTests.swift` |
| События/лейаут | `equinox/Core/EventLayout.swift`, `equinox/Services/EventKit/CalendarStore.swift`, `equinoxTests/EventLayoutTests.swift` |
| Meeting URLs | `equinox/Core/JoinURLDetection.swift`, `equinoxTests/JoinURLDetectionTests.swift` |
| UI панели | `equinox/UI/Main/`, `equinox/UI/Design/DesignTokens.swift` |
| Настройки | `equinox/UI/Settings/`, `equinox/Services/PreferencesStore.swift`, `equinox/App/Constants.swift` |
| MCP tool | `mcp/src/tools/`, `bridge/EventKitBridge.swift`, `mcp/test/` |
| Menu bar | `equinox/UI/MenuBar/StatusItemController.swift`, `MenuBarIconRenderer.swift` |
| MCP setup в GUI | `equinox/Services/Platform/McpSetup.swift`, `equinoxTests/McpSetupTests.swift` |
| Plaud link/match | `equinox/App/PlaudCoordinator.swift`, `Services/Plaud/PlaudService.swift`, `Core/PlaudEventMatching.swift`, `equinoxTests/PlaudEventMatchingTests.swift` |
| Plaud OAuth/setup | `PlaudSettingsTab.swift`, `PlaudOAuthClient.swift`, `Core/PlaudOAuthPKCE.swift`, `equinoxTests/PlaudOAuthPKCETests.swift` |
| Privacy / TCC status | `PrivacySettingsTab.swift`, `CalendarAccessMapping.swift`, `AppDelegate` |
| EventKit calendar mapping (app+bridge) | `Services/EventKit/EventKitCalendarMapping.swift` — общий `colorHex`/`calendarTypeLabel`/`calendarListItem`; не дублировать в `CalendarStore` и `EventKitBridge` |

### Структура репозитория

```
equinox/          — macOS menu bar app (Swift/SwiftUI + AppKit)
  App/            — lifecycle, AppState, Constants
  Core/           — чистая логика (тестируемая)
  Services/       — EventKit, preferences, platform helpers
  UI/             — SwiftUI views + Design tokens
bridge/           — equinox-bridge CLI (JSON ↔ EventKit)
mcp/              — TypeScript MCP server
equinoxTests/     — XCTest
scripts/          — run.sh, build-mcp.sh, require-arm64.sh
```

### Xcode-таргеты

| Таргет | Назначение |
|--------|------------|
| `equinox` | GUI-приложение |
| `equinox-bridge` | Headless EventKit CLI |
| `equinoxTests` | Unit-тесты Core/Services |

### Первичная настройка окружения

```bash
cp Local.xcconfig.example Local.xcconfig
```

`Local.xcconfig` — gitignored. **Не коммитить** и **не менять** `DEVELOPMENT_TEAM` / `ProvisioningStyle` в `equinox.xcodeproj/project.pbxproj`.

---

## 4. Правила изменения кода

Агент **обязан**:

- Делать **минимально достаточное** изменение
- **Не переписывать** большие части проекта без явного запроса
- **Не создавать новую архитектуру** ради одной задачи (нет Redux/TCA — не добавлять)
- **Не дублировать** бизнес-логику между `Core/`, `CalendarStore`, `EventKitBridge`, MCP
- **Не добавлять временный код** без явной причины и плана удаления
- **Не оставлять TODO** без контекста, владельца или условия удаления
- **Удалять код**, ставший ненужным после изменения
- **Сохранять стиль проекта**: `@Observable`, `actor`, `Sendable`, `@MainActor` где уже принято
- **Использовать существующие** компоненты: `PanelComponents`, `SettingsComponents`, `SizeMetrics`, Zod-схемы MCP
- **Избегать скрытых сайд-эффектов** — EventKit-мутации только в `CalendarStore` / `EventKitBridge`
- **Не менять публичные контракты** без описания последствий:
  - MCP tool names и input schemas
  - bridge JSON commands (`access_status`, `list_events`, `create_event`, …)
  - UserDefaults keys (`k*` в `Constants.swift`)
  - URL scheme `equinox://date/yyyy-MM-dd`

### Слои и границы

| Слой | Можно | Нельзя |
|------|-------|--------|
| `Core/` | Чистые функции, `CalendarDate` | AppKit, SwiftUI, EventKit, сеть |
| `Services/` | EventKit, UserDefaults, ScriptingBridge | SwiftUI views |
| `UI/` | Презентация, `@Bindable AppState` | Прямой доступ к `EKEventStore` |
| `bridge/` | EventKit CLI, JSON protocol | Зависимость от GUI |
| `mcp/` | MCP tools, Zod, аналитика в Node | Прямой EventKit (только через bridge) |

### Состояние

- `AppState` — `@Observable @MainActor`, навигация и кэш событий
- `PreferencesStore.shared` — `@Observable`, персистентные настройки
- `CalendarStore` — `actor`, единственный шлюз EventKit в GUI
- Уведомления: `kEquinoxSizePreferenceChanged`, `kEquinoxMenuBarAppearanceChanged` (события календаря — через `EventsCoordinator.syncFromCalendarStore()`)

### Гибрид AppKit + SwiftUI

- AppKit: `StatusItemController` — status item, popover, pinned panel, settings window
- SwiftUI: `MainPanelView`, `SettingsView` через `NSHostingController`
- Не переносить window chrome в SwiftUI без явной задачи

### Release-only локальная сборка

Локальный запуск — **только Release** (`./run.sh` собирает app, при необходимости bridge и MCP; схема `equinox` pinned to Release). Не вводить поведение, работающее только в Debug.

---

## 5. Правила для вайбкодинга

Правила, делающие проект дешёвым для AI-агентов:

- **Говорящие имена**: `MonthGrid`, `DayEvent`, `JoinURLDetection`, `invokeBridge`, `requireBridgeData`
- **Маленькие функции** с одной ответственностью; `Core/` — чистые функции без состояния
- **Явные входы и выходы**: `CalendarDate`, `DayEvent`, `BridgeResponse<T>`, Zod input schemas
- **Без неочевидной магии**: не прятать EventKit в computed properties view; не использовать reflection
- **Минимальная связность**: `SizeMetrics` передаётся параметром, не через глобальный environment
- **Понятная структура файлов**: feature-папки в `UI/Main/`, `UI/Settings/`, `UI/Events/`
- **Комментарии** — только причина, не пересказ кода (пример: `kPinnedPanelVisible` для restore pinned panel)
- **Рядом с нетривиальной логикой — тесты**: `EventLayout` → `EventLayoutTests.swift`
- **Сложная бизнес-логика изолирована от UI**: сетка, лейаут, URL detection — в `Core/`
- **UI-компоненты без тяжёлой бизнес-логики**: view вызывает `appState.createEvent(from:)`, не строит `EKEvent` сам

### MCP-конвенции

- Регистрация tools: `mcp/src/tools/calendars.ts`, `events.ts`, `index.ts`
- Валидация входа — Zod на границе MCP
- Вызов EventKit — `invokeBridge({ command: "..." })` в `mcp/src/bridge.ts`
- Аналитика (`analyze_schedule`, `find_conflicts`, `find_free_time`) — только в Node (`mcp/src/analytics/`), не в GUI
- Путь к bridge: `EQUINOX_BRIDGE_PATH` или `build/DerivedData/Build/Products/Release/equinox-bridge`

---

## 6. Борьба с мёртвым кодом

Строгие правила:

1. **Код не используется — удалить** (функция, view, tool, asset color, entitlement)
2. **Удаляется фича — удалить всё связанное**: компоненты, стили, тесты, моки, флаги (`k*`), MCP tools, bridge-команды, документацию, импорты
3. **Перед добавлением новой сущности** — поиск аналога в `Core/`, `Services/`, `UI/`, `mcp/src/`
4. **Закомментированный код — запрещён**
5. **Абстракции «на будущее» — запрещены** без реального применения в текущей задаче
6. **После изменения проверить**: неиспользуемые экспорты, импорты, типы, Swift files, npm deps

### Чеклист при удалении фичи equinox

- [ ] Swift view / controller
- [ ] `Constants.swift` — `k*`-ключ и enum
- [ ] `PreferencesStore` property + UserDefaults
- [ ] `AppDelegate.registerDefaults()` — если нужен default для нового ключа
- [ ] Settings tab
- [ ] Asset catalog colors/images
- [ ] Entitlements (app и bridge — раздельно)
- [ ] MCP tool + bridge command + test
- [ ] Локализация в `_translations/` / `ru.lproj`
- [ ] Plaud: `PlaudCoordinator`, `PlaudService`, `PlaudLiveClient`, `PlaudRecordingsStore`, `PlaudMatchCache`, `PlaudOAuthClient`, `Core/PlaudEventMatching`, `Core/PlaudOAuthPKCE`, `Core/PlaudTimestamp`, `PlaudSettingsTab`, `kPlaudEnabled`

---

## 7. Стабильность бизнес-сценариев

Перед каждым изменением агент **обязан ответить**:

| Вопрос | Действие |
|--------|----------|
| Какой бизнес-сценарий меняется? | Назвать явно |
| Какие сценарии затронуты косвенно? | Перечислить |
| Какие роли пользователей затронуты? | macOS user с доступом к Calendar |
| Какие edge cases есть? | См. ниже |
| Что при ошибке API/EventKit? | Показать ошибку / пустое состояние / не ломать UI |
| Что при пустых данных? | Empty state в agenda/grid |
| Что при медленной сети? | N/A для EventKit (локально); но fetch может быть медленным — loading |
| Что при повторном действии? | Идемпотентность save/delete |
| Что при частично загруженном состоянии? | `firstVisibleDate`/`lastVisibleDate`, incremental fetch |
| Что должно остаться неизменным? | Явно перечислить |

**Правило:** если агент не может определить бизнес-сценарий — **не делать широкое изменение**. Ограничиться минимальным локальным исправлением и явно описать риск.

### GUI-сценарии (equinox.app)

| Сценарий | Ключевые файлы |
|----------|----------------|
| Просмотр месячной сетки | `CalendarGridView`, `DayCellView`, `MonthGrid` |
| Просмотр agenda | `AgendaView`, `AgendaComponents` |
| Навигация по месяцам | `AppState.monthDate`, `PanelCommandBar` |
| Выбор дня | `AppState.selectedDate`, `DayCellView` / `CalendarGridView` |
| Создание события | `NewEventSheet` → `NewEventDraft` → `AppState.createEvent(from:)` |
| Просмотр/удаление события | `EventDetailView` → `AppState.deleteEvent(identifier:)` |
| RSVP на приглашение | `EventDetailView`, `EventRSVPBar` → `AppState.setParticipationStatus` → `CalendarStore` |
| **Редактирование события в GUI** | **Не поддерживается** — не добавлять без явного запроса |
| Фильтрация календарей | Settings → Calendars, `CalendarSelectionStorage` |
| Pin vs popover | `StatusItemController`, `kPanelPinned` |
| Иконка menu bar | `MenuBarIconRenderer`, настройки icon type |
| Meeting indicator | `kShowMeetingIndicator`, `shouldShowMeetingIndicator` |
| Превью событий при hover | `kShowEventPopoverOnHover`, `DayHoverPreview`, `AppearanceSettingsTab` |
| Global shortcut | MASShortcut, `kKeyboardShortcut` |
| Join meeting (Zoom/Teams/Chime) | `JoinURLDetection`, `NativeJoinURL`, `CalendarStore` URL rewriting |
| Plaud auto-match прошлых встреч | `PlaudCoordinator`, `PlaudService`, `PlaudMatchCache`, `Core/PlaudEventMatching` |
| Plaud manual link записи к событию | `EventDetailView`, `PlaudCoordinator` |
| Plaud OAuth / настройка интеграции | `PlaudSettingsTab`, `PlaudOAuthClient`, `Core/PlaudOAuthPKCE`, `kPlaudEnabled` |
| Privacy / статус доступа к календарю | `PrivacySettingsTab`, `CalendarAccessMapping`, `AppDelegate` |
| Deep link `equinox://date/yyyy-MM-dd` | `AppDelegate.application(_:open:)` |
| MCP автонастройка (Cursor, Claude) | `McpSettingsTab`, `McpConfigurator` (`equinox/Services/Platform/McpSetup.swift`) |
| Настройки (General, Calendars, Appearance, Privacy, Shortcuts, MCP, Plaud, About) | `SettingsView`, `*SettingsTab` |
| Доступ к календарю (запрос/отказ/отзыв) | `AppDelegate`, System Settings TCC |
| Launch at login | `LaunchAtLogin` (`equinox/Services/Platform/LaunchAtLogin.swift`) |

### MCP-сценарии (equinox-bridge + mcp/)

**Что такое MCP простыми словами.** Это набор команд, через которые ИИ-ассистент (например, в Cursor или Claude) может работать с календарём пользователя — посмотреть встречи, создать новую, найти свободное время. equinox выступает безопасным посредником: ИИ не лезет в системный календарь macOS напрямую, а только просит выполнить одну из разрешённых ниже команд. Каждая команда делает ровно одно понятное действие.

**1. Доступ (разрешения).** Без разрешения пользователя ассистент календарь не видит — это про безопасность и приватность.

| Команда | Что делает простыми словами | Зачем нужна |
|---------|------------------------------|-------------|
| `get_calendar_access_status` | Проверяет, разрешён ли ассистенту доступ к календарю (ничего не запрашивая) | Понять заранее, можно ли работать, и показать понятную ошибку вместо сбоя |
| `request_calendar_access` | Запрашивает доступ к календарю; может показать системное окно «Разрешить?» | Первичная настройка — пользователь один раз даёт разрешение |

**2. Чтение календаря (ничего не меняет).**

| Команда | Что делает простыми словами | Зачем нужна |
|---------|------------------------------|-------------|
| `list_calendars` | Возвращает список всех календарей (рабочий, личный и т. д.) с названием, цветом и пометкой, можно ли в него писать | Понять, какие календари есть и куда уместно смотреть или добавлять события |
| `list_events` | Возвращает встречи за выбранный период; можно ограничить нужными календарями (до 500 за раз) | Главный способ увидеть, что запланировано на день / неделю / месяц |
| `get_event` | Возвращает одну конкретную встречу со всеми деталями (время, участники, ссылка) | Посмотреть подробности одной встречи |

**3. Изменение календаря (меняет данные — действовать осознанно).**

| Команда | Что делает простыми словами | Зачем нужна |
|---------|------------------------------|-------------|
| `create_event` | Создаёт новую встречу в выбранном или календаре по умолчанию | Ассистент добавляет встречу по просьбе пользователя |
| `update_event` | Меняет часть существующей встречи (например, время или название) | Перенести или поправить встречу |
| `delete_event` | Удаляет встречу (одно повторение или все будущие — для повторяющихся) | Отменить встречу |

**4. Аналитика расписания (только считает, ничего не меняет).**

| Команда | Что делает простыми словами | Зачем нужна |
|---------|------------------------------|-------------|
| `analyze_schedule` | Считает загрузку: сколько минут занято, % занятости, сколько встреч со ссылкой на звонок, события «на весь день» против обычных | Оценить, насколько плотный период; отчётность по загрузке |
| `find_conflicts` | Находит встречи, которые накладываются друг на друга по времени | Заметить двойные брони и пересечения |
| `find_free_time` | Находит свободные окна не короче заданной длины в рабочих часах (по умолчанию 09:00–18:00) | Быстро подобрать время под новую встречу |

### Edge cases — обязательно проверять

- Пустой календарь / нет выбранных календарей
- Многодневные события (`EventLayout`)
- События на границе месяца / видимого диапазона
- Медленный EventKit fetch
- Внешнее изменение календаря (`.EKEventStoreChanged` → refetch)
- Отказ в доступе к календарю — **отдельно для app и bridge**
- Диапазон дат 1583–3333 (`CalendarDate`)
- Переключение размера панели S/M/L
- Переключение pin ↔ popover с сохранением состояния

---

## 8. Стабильность UI/UX

При изменении UI агент **обязан проверить**:

### Состояния

- [ ] Обычное (данные есть)
- [ ] Loading (fetch EventKit)
- [ ] Empty (нет событий / нет календарей)
- [ ] Error (нет доступа к календарю)
- [ ] Disabled (кнопки, недоступные действия)

### Контент и layout

- [ ] Длинные названия событий и локации
- [ ] Размеры экрана — панель S/M/L (`SizePreference`, `SizeMetrics`)
- [ ] Переполнение в agenda и grid
- [ ] Кликабельные зоны кнопок panel command bar
- [ ] Hover preview (`kShowEventPopoverOnHover`)

### Panel modes

- [ ] Popover (клик по menu bar icon)
- [ ] Pinned floating panel (`kPanelPinned`)
- [ ] Переключение pin ↔ popover
- [ ] Восстановление pinned state после перезапуска (`kPinnedPanelVisible`)

### Menu bar

- [ ] Иконка: date / DOW / hidden (`kHideIcon`)
- [ ] Meeting indicator dot
- [ ] Перерисовка при смене appearance

### Settings

- [ ] Все tabs: General, Calendars, Appearance, Privacy, Shortcuts, About, MCP, Plaud
- [ ] `NavigationSplitView` sidebar
- [ ] Activation policy: `.accessory` ↔ `.regular` при открытии settings

### Визуальная консистентность

- [ ] Цвета через `EquinoxDesign.ColorToken` / asset catalog
- [ ] Glass vs solid background (`BackgroundStyle`)
- [ ] Light / dark / system theme (`ThemePreference`)
- [ ] Анимации перехода месяца (`MainPanelView` transition)
- [ ] **Не менять** отступы, цвета, размеры без задачи на это

### Доступность

- [ ] Фокус в sheets (New Event, Go To Date, Event Detail)
- [ ] Keyboard shortcut (MASShortcut)
- [ ] Локализация — `String(localized:comment:)`

---

## 9. Тестирование и проверки

### Команды (из конфигов проекта)

**Первичная настройка:**
```bash
cp Local.xcconfig.example Local.xcconfig
```

**Сборка и запуск GUI (Release):**
```bash
./run.sh
```

**Swift unit-тесты (XCTest):**
```bash
xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  test
```

**MCP: полная сборка bridge + MCP + тесты:**
```bash
./scripts/build-mcp.sh
```

**MCP: отдельные команды:**
```bash
cd mcp && npm install
cd mcp && npm run build    # tsc -p tsconfig.json, strict: true
cd mcp && npm test         # vitest run
cd mcp && npm run dev      # tsx src/server.ts
```

**Сборка только bridge:**
```bash
xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox-bridge \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

**Release / notarization (ручной процесс):**
Архив в Xcode → нотаризация → экспорт для распространения. См. [BUILD.md](BUILD.md) для полного flow.

### Существующие тесты

**Swift (`equinoxTests/`):**
- `CalendarDateTests.swift`
- `MonthGridTests.swift`
- `EventLayoutTests.swift`
- `JoinURLDetectionTests.swift`
- `EventParticipationTests.swift`
- `EventFetchRangeTests.swift`
- `NativeJoinURLTests.swift`
- `DayEventDotColorsTests.swift`
- `McpSetupTests.swift`
- `PlaudEventMatchingTests.swift`
- `PlaudTimestampTests.swift`
- `PlaudOAuthPKCETests.swift`
- `EventKitCalendarMappingTests.swift`

**TypeScript (`mcp/test/`):**
- `bridge.test.ts`
- `analytics.test.ts`

### Матрица: что запускать при изменении

| Изменено | Обязательные проверки |
|----------|---------------------|
| `equinox/Core/*` | `xcodebuild test` + релевантный XCTest |
| `equinox/Services/EventKit/CalendarStore.swift`, `Services/EventKit/EventKitCalendarMapping.swift` | `xcodebuild test` + `./run.sh` + ручная проверка fetch/create/delete/permission |
| `equinox/Services/Plaud*.swift`, `Core/Plaud*.swift` | `xcodebuild test` + `PlaudEventMatchingTests` / `PlaudTimestampTests` / `PlaudOAuthPKCETests` + `./run.sh` |
| `equinox/Services/PreferencesStore.swift`, `Constants.swift` | `./run.sh` + проверка settings persistence |
| `equinox/UI/*` | `./run.sh` + все UI-состояния из раздела 8 |
| `equinox/App/AppState.swift` | `./run.sh` + сценарии навигации и событий |
| `bridge/*` | `xcodebuild -scheme equinox-bridge build` + `./scripts/build-mcp.sh` |
| `mcp/*` | `cd mcp && npm run build && npm test` |
| `equinox.xcodeproj/project.pbxproj` | Diff **не содержит** `DEVELOPMENT_TEAM`, `DevelopmentTeam`, `ProvisioningStyle` |
| MCP config | `.cursor/mcp.json` — `EQUINOX_BRIDGE_PATH` указывает на собранный bridge |

### Что агент проверяет после изменения

1. Запустить релевантные тесты (по матрице выше)
2. Typecheck MCP: `cd mcp && npm run build`
3. Сборка затронутых таргетов (`xcodebuild build` или `./run.sh`)
4. Затронутые бизнес-сценарии — вручную или через тесты
5. UI-состояния из раздела 8 — для UI-изменений
6. Нет мёртвого кода (неиспользуемые импорты, файлы, keys)
7. Diff минимален — нет лишних файлов

### Отсутствующие проверки

В проекте **нет**:
- SwiftLint / ESLint / Prettier
- Pre-commit hooks
- CI build/test (только signing guard)
- UI-тестов (XCUITest)
- Отдельной команды `typecheck` для Swift

Агент **не должен** писать, что эти проверки выполнены, если они не запускались.

---

## 10. Правила ревью результата

Перед завершением работы агент проходит чеклист:

- [ ] Изменение решает исходную задачу
- [ ] Изменение минимально — нет случайного рефакторинга
- [ ] Нет дублирования логики между app/bridge/MCP/Core
- [ ] Нет мёртвого кода (файлы, импорты, `k*`-ключи, tools)
- [ ] Не сломаны бизнес-сценарии (раздел 7)
- [ ] Не сломан UI/UX (раздел 8)
- [ ] Обработаны edge cases
- [ ] Тесты добавлены/обновлены там, где разумно (особенно `Core/`)
- [ ] Команды проверки выполнены или явно указано, почему нет
- [ ] Риски и предположения описаны
- [ ] `project.pbxproj` не содержит изменений signing settings
- [ ] UserDefaults keys синхронизированы (Constants + PreferencesStore + registerDefaults)
- [ ] Локализация не сломана
- [ ] Не добавлены npm-зависимости без обоснования

---

## 11. Формат ответа агента после выполнения задачи

После каждого изменения агент отвечает в формате:

```markdown
## Что изменено
- ...

## Почему так
- ...

## Проверки
- [x] ...
- [ ] ... (не выполнено — причина)

## Риски
- ...

## Что не сделано
- ...
```

---

## 12. Запреты

Явный список запретов:

1. **Большой рефакторинг** без явного запроса пользователя
2. **Смена архитектуры** без необходимости (новые state management frameworks, DI containers)
3. **Абстракции «на будущее»** без текущего применения
4. **Мёртвый код** — оставлять неиспользуемое
5. **Скрывать неуверенность** — риски и предположения обязательны
6. **Врать о проверках** — не отмечать [x] без реального запуска
7. **Менять бизнес-логику** без описания последствий для сценариев
8. **Случайные UI-изменения** — отступы, цвета, размеры, анимации
9. **Игнорировать паттерны проекта** — слои, actor, @Observable, DesignTokens
10. **Новые зависимости** (npm, SPM, frameworks) без обоснования
11. **Менять signing settings** в `project.pbxproj` — только `Local.xcconfig`
12. **Debug-only поведение**, расходящееся с Release production build
13. **Прямой EventKit в UI** — минуя `CalendarStore`
14. **Прямой EventKit в MCP** — минуя `equinox-bridge`
15. **Закомментированный код**
16. **Дублирование** логики `JoinURLDetection` / `EventLayout` / calendar fetch в нескольких местах

---

## Критичные правила equinox (краткая сводка)

1. **EventKit только через шлюзы** — `CalendarStore` (app) и `EventKitBridge` (CLI); изменение в одном пути → проверить второй
2. **`Core/` остаётся чистым** — новая бизнес-логика сначала сюда + XCTest
3. **Минимальный UI diff** — `SizeMetrics`, `DesignTokens`, `PanelComponents`
4. **Signing только в `Local.xcconfig`** — не трогать `project.pbxproj`
5. **Удалять мёртвый код синхронно** — keys, tools, tabs, assets, entitlements
6. **Release = production** — локальный `./run.sh` всегда Release
7. **Два TCC-разрешения** — app и bridge независимы
8. **Локализация** — `String(localized:comment:)`

---

## Unknown / needs clarification

Данные, которые не удалось зафиксировать однозначно. Перед широкими изменениями — уточнить у владельца проекта.

| Тема | Статус | Что уточнить |
|------|--------|--------------|
| CI build/test | Отсутствует (только signing guard) | Добавить workflow для `xcodebuild test` и `build-mcp.sh`? |
| SwiftLint / форматирование Swift | Отсутствует | Нужен ли `.swiftlint.yml` и правила форматирования? |
| UI-тесты (XCUITest) | Отсутствуют | Нужны ли автотесты для panel/popover/settings? |
| Синхронизация app vs bridge | Документировано | См. [ARCHITECTURE.md](ARCHITECTURE.md) — app vs bridge matrix |
| Source provenance | Есть предупреждение | `.source-provenance.txt` указывает на unofficial source; какая политика для upstream sync? |
| MCP update_event в GUI | Расхождение | MCP поддерживает `update_event`, GUI — нет; намеренно |
| Политика новых MCP tools | Не документирована | Кто решает, какие tools добавлять; нужна ли версионизация протокола bridge? |
| Notarization/release | Ручной процесс | Кто выполняет release; нужна ли автоматизация archive/notarize? |
| Минимальная версия macOS | 26.0 | Намеренно ли; нужна ли поддержка older macOS? |

### App vs bridge behavior

| Поведение | GUI | Bridge/MCP |
|-----------|-----|------------|
| Declined invitations | Показываются, dimmed | Фильтруются (`isDeclined`) |
| Join URL | Web + native rewrite (`NativeJoinURL`) | Только web (`JoinURLDetection`) |
| Multi-day events | `EventLayout` day slots | Один flat event |
| Calendar filter | `CalendarSelectionStorage` | Все календари, если не передан `calendarIds` |
| RSVP | `setParticipationStatus` | Нет команды |
| `update_event` | Нет в GUI | Есть в MCP |

См. также [ARCHITECTURE.md](ARCHITECTURE.md).
