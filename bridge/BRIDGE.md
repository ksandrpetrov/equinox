# Протокол equinox-bridge

Headless CLI поверх EventKit, используемый MCP-сервером equinox. Одна JSON-команда передаётся как **единственный аргумент argv** (не stdin); один JSON-ответ пишется в stdout.

## Обзор

```
AI-клиент (Cursor / Codex / Claude)
        ↓ MCP invokeBridge()
mcp/dist/server.js
        ↓ spawn equinox-bridge '<json>'
equinox-bridge (EventKitBridge)
        ↓ EKEventStore
macOS Calendar
```

Bridge и GUI-приложение используют общий маппинг календарей (`EventKitCalendarMapping`) и чистую логику из `Core/` (`JoinURLDetection` и др.), но имеют задокументированные различия в поведении — см. [ARCHITECTURE.md](../ARCHITECTURE.md).

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

### `update_event`

**Запрос:** частичные поля + обязательный `eventIdentifier`.

**Данные ответа:** envelope мутации (как у create).

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

Поля включают: `eventIdentifier`, `title`, `startDate`, `endDate`, `isAllDay`, `location`, `notes`, `url`, `joinURL` (web URL через `JoinURLDetection`), `calendarIdentifier`, `calendarColorHex`, `allowsContentModifications`, `hasAttendees`.

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
