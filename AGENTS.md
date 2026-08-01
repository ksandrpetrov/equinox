# AGENTS.md — инструкция для AI-агентов и разработчиков

## 1. Назначение

Обязательная инструкция для любых AI-агентов и разработчиков, меняющих репозиторий equinox.

Цель: любое изменение должно **повышать или хотя бы не ухудшать** поддерживаемость, стабильность продукта, бизнес-сценариев и UI/UX.

**Приоритет:** при конфликте скорости генерации и поддерживаемости — всегда выбирать поддерживаемость, стабильность и сохранение бизнес-сценариев.

Справочники: [BUILD.md](BUILD.md) (сборка и подпись), [ARCHITECTURE.md](ARCHITECTURE.md) (слои и ключевые потоки).

---

## 2. Метрики качества

Каждое изменение оценивается по шести метрикам.

### 2.1. Поддерживаемость

- Бизнес-логика дат/сетки/лейаута — в `equinox/Core/`, без AppKit/SwiftUI/EventKit
- EventKit — только через `CalendarStore`
- UI — только в `equinox/UI/`, получает `AppState` и `SizeMetrics` явно

### 2.2. Дешевизна при вайбкодинге

- Константы UserDefaults — `let k*` в `equinox/App/Constants.swift`
- Говорящие имена, маленькие функции, явные контракты (`CalendarDate`, `DayEvent`, `NewEventDraft`)
- `SizeMetrics` передаётся параметром, не через environment
- Чистые функции в `Core/` + XCTest в `equinoxTests/`; view вызывает `appState.createEvent(from:)`, не строит `EKEvent`
- **UI access:** мутации через `AppState` facade; чтение и `@Bindable` — напрямую `appState.events` / `panel` / `plaud` (см. `ARCHITECTURE.md` § UI access patterns)

### 2.3. Отсутствие мёртвого кода

Запрещены неиспользуемые компоненты, флаги, ветки, неактуальные комментарии, временные обходы без срока жизни, закомментированный код, абстракции «на будущее».

При удалении фичи синхронно убрать: Swift view/controller, `k*`-ключи в `Constants.swift`, `PreferencesStore`, settings tab, assets, entitlements, тесты и локализацию. Для Plaud — весь стек (`PlaudCoordinator`, `PlaudService`, `PlaudLiveClient`, `PlaudRecordingsStore`, `PlaudMatchCache`, `PlaudOAuthClient`, `Core/Plaud*`, `PlaudSettingsTab`, `kPlaudEnabled`).

### 2.4. Стабильность продукта

- `CalendarStore` — `actor`; не нарушать изоляцию EventKit
- `NotificationCenter`: `kEquinoxSizePreferenceChanged`, `kEquinoxMenuBarAppearanceChanged` — не ломать подписчиков (события календаря — через `EventsCoordinator.syncFromCalendarStore()`)
- Разрешение Calendar в TCC принадлежит `equinox.app`

### 2.5. Стабильность бизнес-сценариев

Перед изменением определить затронутые сценарии (раздел 7). Нельзя менять поведение без описания последствий. Если сценарий неясен — минимальное локальное исправление + явный риск.

### 2.6. Стабильность UI/UX

- `DesignTokens.swift`, `PanelComponents`, `SettingsComponents`
- Размеры S/M/L через `SizeMetrics` — не хардкодить пиксели
- Строки — `String(localized:comment:)`; есть `ru.lproj` и `_translations/`

---

## 3. Перед началом работы

1. Прочитать файл и соседей (импорты, вызовы, тесты)
2. Поиск аналогов в репозитории
3. Проверить слои `App/`, `Core/`, `Services/`, `UI/`
4. Понять бизнес-сценарии (раздел 5) и UI-регрессии (раздел 6)
5. Найти тесты в `equinoxTests/`
6. Расширять существующее (`CalendarStore`, `PreferencesStore`, `DesignTokens`), не создавать новый механизм
7. Зафиксировать допущения и ограничения в ответе (раздел 8)

### Карта «куда смотреть первым»

| Задача | Сначала изучить |
|--------|-----------------|
| Сетка/даты | `Core/MonthGrid.swift`, `Core/CalendarDate.swift`, `equinoxTests/MonthGridTests.swift` |
| События/лейаут | `Core/EventLayout.swift`, `Services/EventKit/CalendarStore.swift` |
| Meeting URLs | `Core/JoinURLDetection.swift`, `equinoxTests/JoinURLDetectionTests.swift` |
| UI панели | `UI/Main/`, `UI/Design/DesignTokens.swift` |
| Настройки | `UI/Settings/`, `Services/PreferencesStore.swift`, `App/Constants.swift` |
| Menu bar | `UI/MenuBar/StatusItemController.swift`, `MenuBarIconRenderer.swift` |
| Plaud | `App/PlaudCoordinator.swift`, `Services/Plaud/`, `Core/PlaudEventMatching.swift` |
| Privacy / TCC | `PrivacySettingsTab.swift`, `CalendarAccessMapping.swift`, `AppDelegate` |
| Calendar mapping | `Services/EventKit/EventKitCalendarMapping.swift` — не дублировать в `CalendarStore` |

### Структура

```
equinox/     — macOS menu bar app (Swift/SwiftUI + AppKit)
  App/       — lifecycle, AppState, Constants
  Core/      — чистая логика
  Services/  — EventKit, preferences, platform
  UI/        — SwiftUI + Design tokens
equinoxTests/
run.sh       — сборка и запуск GUI (Release)
scripts/     — вспомогательные скрипты сборки и проверки
```

| Таргет | Назначение |
|--------|------------|
| `equinox` | GUI |
| `equinoxTests` | Unit-тесты |

```bash
cp Local.xcconfig.example Local.xcconfig
```

`Local.xcconfig` — gitignored. **Не коммитить** и **не менять** `DEVELOPMENT_TEAM` / `ProvisioningStyle` в `project.pbxproj`.

---

## 4. Правила изменения кода

- Минимально достаточный diff; без большого рефакторинга и новой архитектуры (нет Redux/TCA)
- Не дублировать логику между `Core/` и `CalendarStore`
- Не оставлять TODO без контекста; удалять код, ставший ненужным
- Стиль: `@Observable`, `actor`, `Sendable`, `@MainActor` где принято
- EventKit-мутации только в `CalendarStore`
- Не менять публичные контракты без описания последствий: `k*` keys, `equinox://date/yyyy-MM-dd`
- **Запрещено:** signing в `project.pbxproj`, Debug-only поведение, прямой EventKit в UI, новые зависимости без обоснования, случайные UI-изменения, врать о проверках

### Слои

| Слой | Можно | Нельзя |
|------|-------|--------|
| `Core/` | Чистые функции | AppKit, SwiftUI, EventKit, сеть |
| `Services/` | EventKit, UserDefaults | SwiftUI views |
| `UI/` | Презентация, `@Bindable AppState` | Прямой `EKEventStore` |

### Состояние

- `AppState` — `@Observable @MainActor`
- `PreferencesStore.shared` — `@Observable @MainActor`, персистентные настройки
- `CalendarStore` — `actor`, единственный шлюз EventKit в GUI
- AppKit: `StatusItemController` (status item, popover, pinned panel); SwiftUI: `MainPanelView`, `SettingsView`
- Локальный запуск — **только Release** (`./run.sh`)

---

## 5. Бизнес-сценарии

Перед изменением ответить: какой сценарий меняется, косвенные затронутые, edge cases, что при ошибке/пустых данных, что остаётся неизменным.

### GUI (equinox.app)

| Сценарий | Ключевые файлы |
|----------|----------------|
| Месячная сетка | `CalendarGridView`, `DayCellView`, `MonthGrid` |
| Agenda | `AgendaView`, `AgendaComponents` |
| Навигация / выбор дня | `AppState.monthDate`, `AppState.selectedDate`, `PanelCommandBar` |
| Создание события | `NewEventSheet` → `NewEventDraft` → `AppState.createEvent(from:)` |
| Просмотр/удаление | `EventDetailView` → `AppState.deleteEvent` |
| RSVP | `EventRSVPBar` → `AppState.setParticipationStatus` → `CalendarStore` |
| **Редактирование в GUI** | **Не поддерживается** |
| Фильтр календарей | Settings → Calendars, `CalendarSelectionStorage` |
| Pin vs popover | `StatusItemController`, `kPanelPinned` |
| Menu bar icon | `MenuBarIconRenderer`, настройки icon type |
| Meeting indicator | `kShowMeetingIndicator` |
| Global shortcut | `KeyboardShortcuts` (миграция с MASShortcut), `KeyboardShortcutMigration` |
| Join meeting | `JoinURLDetection`, `NativeJoinURL` |
| Plaud auto/manual match | `PlaudCoordinator`, `PlaudService`, `PlaudMatchCache` |
| Plaud OAuth | `PlaudSettingsTab`, `PlaudOAuthClient`, `Core/PlaudOAuthPKCE` |
| Privacy / TCC | `PrivacySettingsTab`, `AppDelegate` |
| Deep link `equinox://date/yyyy-MM-dd` | `AppDelegate.application(_:open:)` |
| Настройки (7 tabs) | `SettingsView`, `*SettingsTab` |
| Launch at login | `LaunchAtLogin.swift` |

### Edge cases

Пустой календарь; многодневные события; границы месяца; медленный EventKit fetch; `.EKEventStoreChanged`; TCC-разрешение приложения; даты 1583–3333; размеры S/M/L; pin ↔ popover.

---

## 6. UI/UX чеклист

При изменении UI проверить: loading/empty/error/disabled; длинные названия; S/M/L (`SizeMetrics`); popover и pinned panel (`kPanelPinned`, `kPinnedPanelVisible`); menu bar icon/hidden/meeting dot; все settings tabs; `EquinoxDesign.ColorToken`; glass/solid; light/dark/system; фокус в sheets; `KeyboardShortcuts`; локализация. **Не менять** отступы/цвета/размеры без задачи.

---

## 7. Тестирование

```bash
./run.sh                                    # GUI Release
. scripts/xcodebuild-local-settings.sh
load_xcodebuild_local_settings Local.xcconfig
xcodebuild -project equinox.xcodeproj -scheme equinox -configuration Debug \
  -derivedDataPath build/DerivedData test "${XCODEBUILD_LOCAL_SETTINGS[@]}" # Swift tests
```

Тесты: все `equinoxTests/*.swift` (не перечислять вручную — список гниёт).

| Изменено | Проверки |
|----------|----------|
| `equinox/Core/*` | `xcodebuild test` |
| `CalendarStore`, `EventKitCalendarMapping` | test + `./run.sh` + fetch/create/delete |
| Plaud (`Services/Plaud*`, `Core/Plaud*`) | test + `./run.sh` |
| `PreferencesStore`, `Constants.swift` | `./run.sh` + persistence |
| `equinox/UI/*` | `./run.sh` + UI чеклист (раздел 6) |
| `project.pbxproj` | diff **без** `DEVELOPMENT_TEAM` |

**Нет в проекте:** SwiftLint, ESLint, pre-commit, CI build/test (только signing guard), XCUITest. Не отмечать [x] без реального запуска.

---

## 8. Ревью и формат ответа

Чеклист: задача решена; diff минимален; нет дублирования и мёртвого кода; сценарии и UI не сломаны; тесты обновлены где разумно; `k*` синхронизированы (Constants + PreferencesStore + registerDefaults); signing не в pbxproj.

```markdown
## Что изменено
## Почему так
## Проверки
## Риски
## Что не сделано
```

---

## Критичные правила (сводка)

1. EventKit только через `CalendarStore`
2. `Core/` чистый — логика + XCTest
3. Минимальный UI diff — `SizeMetrics`, `DesignTokens`, `PanelComponents`
4. Signing только в `Local.xcconfig`
5. Удалять мёртвый код синхронно
6. Release = production (`./run.sh`)
7. TCC-разрешение принадлежит приложению
8. Локализация — `String(localized:comment:)`

---

## Unknown / needs clarification

| Тема | Статус |
|------|--------|
| CI build/test | Отсутствует |
| SwiftLint | Отсутствует |
| XCUITest | Отсутствуют |
| Notarization | Ручной процесс, см. BUILD.md |
| macOS min 26.0 | Текущий target |

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
