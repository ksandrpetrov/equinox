# Equinox Calendar MCP

TypeScript MCP-сервер в `mcp/`, предоставляющий доступ к календарю macOS и аналитику расписания через `equinox-bridge`.

## Настройка

```bash
./scripts/build-mcp.sh
```

Включите из [`.cursor/mcp.json`](../.cursor/mcp.json) или вкладки Настройки equinox → MCP.

Переменные окружения:

| Переменная | Назначение |
|------------|------------|
| `EQUINOX_BRIDGE_PATH` | Путь к бинарю `equinox-bridge` (по умолчанию: `build/DerivedData/Build/Products/Release/equinox-bridge`) |

**TCC:** у `equinox-bridge` отдельное разрешение на доступ к календарю, не связанное с `equinox.app`.

## Разработка

```bash
cd mcp
npm install
npm run dev    # tsx src/server.ts
npm run build  # tsc -p tsconfig.json
npm test       # vitest
```

## Инструменты (11)

### Доступ к календарю

| Инструмент | Команда bridge | Примечания |
|------------|----------------|------------|
| `get_calendar_access_status` | `access_status` | Только чтение |
| `request_calendar_access` | `request_access` | Может показать системный диалог |
| `list_calendars` | `list_calendars` | |

### События

| Инструмент | Команда bridge | Ключевые поля Zod-схемы |
|------------|----------------|-------------------------|
| `list_events` | `list_events` | `startDate`, `endDate` (YYYY-MM-DD), опц. `calendarIds`, `limit` ≤ 500 |
| `get_event` | `get_event` | `eventIdentifier` |
| `create_event` | `create_event` | `title`, `startDate`, `endDate`, опц. `calendarId`, `allDay`, `location`, `notes`, `url` |
| `update_event` | `update_event` | `eventIdentifier` + частичные поля |
| `delete_event` | `delete_event` | `eventIdentifier`, опц. `span`: `thisEvent` \| `futureEvents` |

### Аналитика (только Node, в памяти)

| Инструмент | Зависит от | Назначение |
|------------|------------|------------|
| `analyze_schedule` | `list_events` | Занятые минуты, % загрузки, статистика join URL |
| `find_conflicts` | `list_events` | Пересекающиеся события со временем |
| `find_free_time` | `list_events` | Свободные слоты в рабочих часах |

Реализация: `mcp/src/analytics/schedule.ts`

## Ресурсы

| URI | Содержимое |
|-----|------------|
| `equinox://docs/calendar` | Обзор в Markdown (также в `src/resources.ts`) |
| `equinox://schema/event` | JSON Schema для `BridgeEvent` |

## Протокол

MCP-инструменты валидируют вход через **Zod** на границе, вызывают `invokeBridge()` в `src/bridge.ts` и возвращают JSON через `requireBridgeData()`.

Протокол bridge: [../bridge/BRIDGE.md](../bridge/BRIDGE.md)

## Ограничения

- Только macOS
- Отклонённые приглашения скрыты в bridge/MCP (GUI показывает их dimmed)
- Нет RSVP через MCP
- Аналитика считается только по загруженному диапазону (максимум 500 событий на один `list_events`)
