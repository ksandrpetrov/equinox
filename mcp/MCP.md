# Calendar MCP

TypeScript MCP-сервер в `mcp/`, предоставляющий доступ к календарю macOS и аналитику расписания через `equinox-bridge`.

## Требования

- macOS с EventKit (только macOS).
- Собранный `equinox-bridge` (Release).
- Node.js для запуска `mcp/dist/server.js`.

## Сборка

```bash
./scripts/build-mcp.sh
```

Скрипт собирает bridge, устанавливает npm-зависимости, компилирует TypeScript и запускает vitest.

## Настройка клиентов

### Через equinox (рекомендуется)

1. Откройте equinox → Settings → MCP.
2. Убедитесь, что Node.js, bridge и MCP-сервер отмечены как готовые.
3. Включите **Auto-configure Cursor and Claude** — equinox запишет сервер `equinox-calendar` в:
   - конфиг Cursor (`~/.cursor/mcp.json` или путь из `McpConfigurator.cursorUserConfigPath()`);
   - конфиг Claude Desktop.
4. Для **Codex** скопируйте TOML-сниппет на вкладке MCP в `~/.codex/config.toml`.

### Вручную

Пример JSON (пути подставляются на вкладке MCP):

```json
{
  "mcpServers": {
    "equinox-calendar": {
      "command": "/path/to/node",
      "args": ["/path/to/equinox/mcp/dist/server.js"],
      "env": {
        "EQUINOX_BRIDGE_PATH": "/path/to/equinox-bridge"
      }
    }
  }
}
```

### Переменные окружения

| Переменная | Назначение |
|------------|------------|
| `EQUINOX_BRIDGE_PATH` | Путь к бинарю `equinox-bridge` (по умолчанию: `build/DerivedData/Build/Products/Release/equinox-bridge`) |

### TCC

У `equinox-bridge` **отдельное** разрешение на доступ к календарю, не связанное с `equinox.app`. Статус проверяется инструментом `get_calendar_access_status`; запрос — `request_calendar_access`.

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

Реализация аналитики: `mcp/src/analytics/schedule.ts`. Аналитика не дублируется в GUI.

## Ресурсы MCP

| URI | Содержимое |
|-----|------------|
| `equinox://docs/calendar` | Обзор в Markdown (также в `src/resources.ts`) |
| `equinox://schema/event` | JSON Schema для `BridgeEvent` |

## Протокол

MCP-инструменты валидируют вход через **Zod** на границе, вызывают `invokeBridge()` в `src/bridge.ts` и возвращают JSON через `requireBridgeData()`.

Протокол bridge: [../bridge/BRIDGE.md](../bridge/BRIDGE.md)

Регистрация инструментов: `mcp/src/tools/calendars.ts`, `events.ts`, `index.ts`.

## Ограничения

- Только macOS и Apple Silicon для сборки (см. `scripts/require-arm64.sh`).
- Отклонённые приглашения скрыты в bridge/MCP (GUI показывает их dimmed).
- Нет RSVP через MCP.
- Join URL в bridge — только web (`JoinURLDetection`); GUI дополнительно переписывает на нативные приложения.
- Аналитика считается только по загруженному диапазону (максимум 500 событий на один `list_events`).
- Редактирование событий в GUI не поддерживается; в MCP — `update_event`.

## См. также

- [BUILD.md](../BUILD.md) — сборка и запуск
- [ARCHITECTURE.md](../ARCHITECTURE.md) — различия поведения app и bridge
