# Протокол equinox-bridge

`equinox-bridge` — headless CLI поверх EventKit, используемый Calendar MCP. Одна JSON-команда передаётся как **единственный аргумент argv** (не stdin); один JSON-ответ пишется в stdout.

Bridge умеет только EventKit-операции: проверить/запросить доступ, перечислить календари, прочитать события, создать, частично обновить или удалить событие. Plaud, prompts, resources и аналитика расписания реализованы выше, в MCP-сервере.

## Обзор

```
AI-клиент (Cursor / Codex / Claude)
        ↓ MCP invokeBridge()
mcp/dist/server.js
        ↓ HTTP localhost (основной путь)
equinox.app app bridge proxy
        ↓ spawn equinox-bridge '<json>'
equinox-bridge (EventKitBridge)
        ↓ EKEventStore
macOS Calendar

Fallback: mcp/dist/server.js → spawn equinox-bridge '<json>'
```

Bridge и GUI-приложение используют общий маппинг календарей (`EventKitCalendarMapping`) и чистую логику из `Core/` (`JoinURLDetection`, RSVP mapping и др.), но имеют задокументированные различия в поведении — см. [ARCHITECTURE.md](../ARCHITECTURE.md).

Основной MCP-путь обычно не запускает bridge напрямую из AI-клиента: `mcp/src/bridge.ts` сначала пробует локальный app bridge proxy внутри запущенного `equinox.app`, а уже он запускает `equinox-bridge`. Если приложение не запущено, MCP делает direct fallback на bridge.

## Envelope

**Успех:**

```json
{ "ok": true, "data": { ... } }
```

**Ошибка:**

```json
{ "ok": false, "error": { "code": "invalid_request", "message": "..." } }
```

## Коды ошибок

| Код | Значение |
|-----|----------|
| `invalid_request` | Некорректный JSON или отсутствующие/невалидные поля |
| `unknown_command` | Нераспознанный `command` |
| `access_denied` | TCC не выдан для equinox-bridge |
| `not_found` | Событие или элемент календаря не найдены (отклонённые приглашения возвращают `not_found` на `get_event`) |
| `read_only_calendar` | Целевой календарь запрещает изменения |
| `save_failed` | Ошибка сохранения в EventKit |
| `delete_failed` | Ошибка удаления в EventKit |
| `internal_error` | Необработанная внутренняя ошибка bridge |

## Команды

| Команда | Назначение | Меняет календарь |
|---------|------------|------------------|
| `access_status` | Статус Calendar permission | Нет |
| `request_access` | Запрос Calendar permission | Нет, но может показать системный TCC-диалог |
| `list_calendars` | Список EventKit-календарей | Нет |
| `list_events` | События за диапазон | Нет |
| `get_event` | Одно событие по `eventIdentifier` | Нет |
| `create_event` | Создать событие | Да |
| `update_event` | Частично обновить событие | Да |
| `delete_event` | Удалить событие | Да |

### `access_status`

**Запрос:** `{ "command": "access_status" }`

**Данные ответа:** `{ "status": "full_access", "granted": true }`

Значения статуса: `full_access`, `write_only`, `not_determined`, `restricted`, `denied`, `unknown`.

GUI (`equinox.app`) может показывать legacy `authorized`; bridge возвращает `full_access` / `write_only`.

### `request_access`

**Запрос:** `{ "command": "request_access" }`

**Данные ответа:** `{ "granted": true, "status": "full_access" }`

Может показать системный диалог разрешения доступа к календарю.

### `list_calendars`

**Запрос:** `{ "command": "list_calendars" }`

**Данные ответа:** `{ "calendars": [ BridgeCalendar, ... ] }`

`BridgeCalendar` включает `id`, `title`, `sourceTitle`, `sourceIdentifier`, `colorHex`, `allowsContentModifications`, `isSubscribed`, `type`.

### `list_events`

**Запрос:**

```json
{
  "command": "list_events",
  "startDate": "2026-06-01",
  "endDate": "2026-06-30",
  "calendarIds": ["optional-id"],
  "limit": 500
}
```

Даты: `YYYY-MM-DD` (границы дня) или ISO-8601 instant. Максимум 500 событий; `truncated: true`, когда срабатывает ограничение.

Отклонённые приглашения **отфильтровываются** (в отличие от GUI, где они показываются dimmed).

**Данные ответа:** `{ "events": [ BridgeEvent, ... ], "truncated": false }`

### `get_event`

**Запрос:** `{ "command": "get_event", "eventIdentifier": "..." }`

Отклонённые приглашения возвращают `not_found`.

**Данные ответа:** `{ "event": BridgeEvent }`

### `create_event`

**Запрос:**

```json
{
  "command": "create_event",
  "title": "Standup",
  "startDate": "2026-06-13T10:00:00.000Z",
  "endDate": "2026-06-13T10:30:00.000Z",
  "calendarId": "optional",
  "allDay": false,
  "location": "",
  "notes": "",
  "url": "https://..."
}
```

**Данные ответа:** `{ "eventIdentifier": "...", "calendarItemIdentifier": "..." }`

Если `calendarId` не передан, bridge использует `defaultCalendarForNewEvents`. Read-only календарь возвращает `read_only_calendar`. Bridge-создание поддерживает только базовые поля события; recurrence, alerts и timezone остаются GUI-only возможностями `CalendarStore`.

### `update_event`

**Запрос:** частичные поля + обязательный `eventIdentifier`.

```json
{
  "command": "update_event",
  "eventIdentifier": "...",
  "title": "Updated title",
  "startDate": "2026-06-13T11:00:00.000Z",
  "endDate": "2026-06-13T11:30:00.000Z",
  "calendarId": "optional",
  "allDay": false,
  "location": "",
  "notes": "",
  "url": "https://..."
}
```

**Данные ответа:** envelope мутации (как у create).

Обновляются только переданные поля. Для recurring-события bridge сохраняет одно EventKit-событие со span `.thisEvent`.

### `delete_event`

**Запрос:**

```json
{
  "command": "delete_event",
  "eventIdentifier": "...",
  "span": "thisEvent"
}
```

`span`: `thisEvent` (по умолчанию) или `futureEvents`.

## Форма события (`BridgeEvent`)

См. MCP-ресурс `equinox://schema/event` или `bridge/BridgeModels.swift`.

Поля включают:

| Поле | Значение |
|------|----------|
| `eventIdentifier` | EventKit identifier для операций `get_event`, `update_event`, `delete_event`; может быть `null` |
| `calendarItemIdentifier` | Стабильный calendar item identifier |
| `title` | Название события |
| `location`, `notes`, `url` | Базовые поля EventKit |
| `startDate`, `endDate` | ISO-8601 instant |
| `isAllDay` | All-day флаг |
| `joinURL` | Web meeting URL, найденный `JoinURLDetection` в location/url/notes |
| `calendarIdentifier`, `calendarTitle`, `calendarColorHex` | Календарь события |
| `allowsContentModifications` | Можно ли менять событие в его календаре |
| `hasAttendees` | Есть ли участники |
| `participationStatus` | RSVP-статус, если применимо |

MCP может дополнительно добавить `hasPlaudRecording` и `plaudRecording`, но это не часть stdout-протокола bridge.

## Сборка

```bash
xcodebuild -project equinox.xcodeproj -scheme equinox-bridge \
  -configuration Release -derivedDataPath build/DerivedData build
```

Или вместе с MCP:

```bash
./scripts/build-mcp.sh
```

Бинарь: `build/DerivedData/Build/Products/Release/equinox-bridge`

Установите `EQUINOX_BRIDGE_PATH` для MCP, если не используете путь DerivedData по умолчанию.

## См. также

- [mcp/MCP.md](../mcp/MCP.md) — инструменты MCP
- [ARCHITECTURE.md](../ARCHITECTURE.md) — различия app vs bridge
