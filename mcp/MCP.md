# Calendar MCP

TypeScript MCP-сервер в `mcp/`, предоставляющий AI-клиентам локальный доступ к календарю macOS через Equinox. Он умеет проверять доступ, читать календари и события, создавать/обновлять/удалять события, анализировать расписание, искать конфликты и свободные окна, а также читать локальный кэш Plaud-записей Equinox.

## Что умеет

| Категория | Возможности |
|-----------|-------------|
| Доступ | Проверить или запросить Calendar permission macOS |
| Календари | Получить список календарей, источников, цветов, типов и writable/read-only статуса |
| События | Прочитать диапазон событий, получить одно событие, создать, частично обновить или удалить событие |
| Аналитика | Посчитать загрузку, найти пересечения, найти свободные окна в рабочих часах |
| Plaud | Прочитать статус локального Plaud-кэша, найти записи за дату/диапазон, дополнить события cached Plaud-ссылками |
| Контекст для AI | Prompts `daily_agenda`, `weekly_calendar_review`; resources `equinox://docs/calendar`, `equinox://schema/event` |

## Требования

- macOS с EventKit (только macOS).
- Собранный `equinox-bridge` (Release).
- Node.js для запуска `mcp/dist/server.js`.
- Запущенный `equinox.app` для основного Calendar access пути через app bridge proxy.

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
5. Перезапустите клиент или перезагрузите MCP-серверы и держите `equinox.app` запущенным во время работы с календарём.

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
| `EQUINOX_APP_BRIDGE_STATE_PATH` | Опциональный путь к state-файлу локального Equinox app bridge. По умолчанию: `~/Library/Application Support/com.equinox.equinoxApp/mcp-app-bridge.json` |
| `EQUINOX_PLAUD_CACHE_DIR` | Опциональный путь к локальному кэшу Plaud Equinox. По умолчанию: `~/Library/Application Support/com.equinox.equinoxApp` |

### TCC

Основной путь MCP — через локальный loopback proxy, который поднимает запущенный `equinox.app`. Приложение запускает `equinox-bridge` от своего имени, поэтому macOS применяет Calendar permission Equinox. Это нужно для AI-клиентов без Calendar entitlement: прямой запуск bridge из Cursor/Codex/Claude может быть заблокирован TCC.

Если `equinox.app` не запущен, MCP пробует прямой fallback на `equinox-bridge`. Статус проверяется инструментом `get_calendar_access_status`; запрос — `request_calendar_access`.

## Разработка

```bash
cd mcp
npm install
npm run dev    # tsx src/server.ts
npm run build  # tsc -p tsconfig.json
npm test       # vitest
```

## Инструменты (13)

### Доступ к календарю

| Инструмент | Команда bridge | Примечания |
|------------|----------------|------------|
| `get_calendar_access_status` | `access_status` | Только чтение |
| `request_calendar_access` | `request_access` | Может показать системный диалог |
| `list_calendars` | `list_calendars` | Возвращает source, type, color и `allowsContentModifications` |

### События

| Инструмент | Команда bridge | Ключевые поля Zod-схемы |
|------------|----------------|-------------------------|
| `list_events` | `list_events` | `startDate`, `endDate` (YYYY-MM-DD), опц. `calendarIds`, `limit` ≤ 500, `includePlaud` |
| `get_event` | `get_event` | `eventIdentifier`; по умолчанию дополняется Plaud-полями |
| `create_event` | `create_event` | `title`, `startDate`, `endDate`, опц. `calendarId`, `allDay`, `location`, `notes`, `url` |
| `update_event` | `update_event` | `eventIdentifier` + частичные поля |
| `delete_event` | `delete_event` | `eventIdentifier`, опц. `span`: `thisEvent` \| `futureEvents` |

`list_events` и `get_event` возвращают EventKit-поля bridge. Если в локальном Plaud-кэше есть привязка, MCP добавляет `hasPlaudRecording: true` и объект `plaudRecording`. Для `list_events` это можно отключить через `includePlaud: false`.

### Аналитика (только Node, в памяти)

| Инструмент | Зависит от | Назначение |
|------------|------------|------------|
| `analyze_schedule` | `list_events` | Занятые минуты, % загрузки, статистика join URL |
| `find_conflicts` | `list_events` | Пересекающиеся события со временем |
| `find_free_time` | `list_events` | Свободные слоты в рабочих часах |

### Plaud (только локальный кэш Equinox, read-only)

| Инструмент | Источник | Назначение |
|------------|----------|------------|
| `get_plaud_status` | `plaud-recordings.json`, `plaud-match-cache.json` | Проверить наличие и свежесть локального каталога Plaud и кэша привязок |
| `list_plaud_recordings` | `plaud-recordings.json`, `plaud-match-cache.json` | Найти записи Plaud за день или диапазон, включая уже кэшированные привязки к событиям |

Plaud-инструменты не обращаются в Plaud API, не обновляют каталог и не читают OAuth tokens из Keychain. Каталог обновляет `equinox.app` через вкладку Plaud или фоновые refresh-сценарии.

Реализация аналитики: `mcp/src/analytics/schedule.ts`. Аналитика не дублируется в GUI.

## Prompts

| Prompt | Аргументы | Назначение |
|--------|-----------|------------|
| `daily_agenda` | `date` (`YYYY-MM-DD`) | Собрать повестку одного дня: all-day, расписание, join URL, Plaud-ссылки, свободные окна и риски |
| `weekly_calendar_review` | `startDate`, `endDate` (`YYYY-MM-DD`) | Обзор недели: загрузка, конфликты, свободное время и рекомендации |

## Ресурсы MCP

| URI | Содержимое |
|-----|------------|
| `equinox://docs/calendar` | Обзор в Markdown (также в `src/resources.ts`) |
| `equinox://schema/event` | JSON Schema для события bridge/MCP, включая optional Plaud enrichment поля |

## Протокол

MCP-инструменты валидируют вход через **Zod** на границе, вызывают `invokeBridge()` в `src/bridge.ts` и возвращают JSON через `requireBridgeData()`.

Протокол bridge: [../bridge/BRIDGE.md](../bridge/BRIDGE.md)

Регистрация инструментов: `mcp/src/tools/calendars.ts`, `events.ts`, `plaud.ts`, `index.ts`.

Single source of truth для имён инструментов: `mcp/src/tools/registry.ts`; Swift-каталог в `equinox/Services/Platform/McpToolNames.generated.swift` генерируется из него.

## Ограничения

- Только macOS и Apple Silicon для сборки (см. `scripts/require-arm64.sh`).
- Отклонённые приглашения скрыты в bridge/MCP (GUI показывает их dimmed).
- Нет RSVP через MCP.
- Join URL в bridge — только web (`JoinURLDetection`); GUI дополнительно переписывает на нативные приложения.
- Аналитика считается только по загруженному диапазону (максимум 500 событий на один `list_events`).
- Plaud MCP читает только локальный кэш Equinox; он не ходит в Plaud API, не читает Keychain и не обновляет каталог сам.
- Редактирование событий в GUI не поддерживается; в MCP — `update_event`.
- Bridge не возвращает recurrence rules и alarms; GUI-only создание события может сохранять recurrence и alert через `CalendarStore`.

## См. также

- [BUILD.md](../BUILD.md) — сборка и запуск
- [ARCHITECTURE.md](../ARCHITECTURE.md) — различия поведения app и bridge
