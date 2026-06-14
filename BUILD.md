# Сборка и запуск

Руководство по локальной разработке, запуску приложения, настройке Calendar MCP и release-сборке equinox.

## Что собирается

В репозитории три рабочих части:

| Часть | Что даёт пользователю |
|-------|------------------------|
| `equinox.app` | menu bar календарь: месячная сетка, agenda, создание/удаление событий, RSVP, join meeting, настройки, Plaud-интеграция |
| `equinox-bridge` | headless EventKit CLI для MCP: JSON-команды чтения/создания/обновления/удаления событий |
| `mcp/dist/server.js` | Calendar MCP для AI-клиентов: 13 инструментов, prompts, resources, аналитика расписания и read-only Plaud-кэш |

Обычный локальный запуск через `./run.sh` поднимает именно приложение. MCP нужен только если вы подключаете Cursor, Codex, Claude Desktop или другой MCP-клиент к календарю.

## Требования

- Mac на **Apple Silicon** (arm64). Скрипты `run.sh`, `build-mcp.sh` и `scripts/require-arm64.sh` завершаются с ошибкой на Intel.
- macOS **26.0** или новее.
- **Xcode** — для сборки `equinox`, `equinox-bridge` и `equinoxTests`.
- **Node.js** — для MCP-сервера (`mcp/`); нужен при `./scripts/build-mcp.sh` и при работе MCP-клиентов.

## Первичная настройка

### Подпись кода

Проект использует `Local.xcconfig` для настройки подписи, чтобы данные о подписи не попадали в `project.pbxproj`. Скопируйте пример и при необходимости отредактируйте:

```bash
cp Local.xcconfig.example Local.xcconfig
```

`Local.xcconfig` в `.gitignore` — **не коммитьте** его. Не меняйте `DEVELOPMENT_TEAM` / `ProvisioningStyle` в `equinox.xcodeproj/project.pbxproj`.

Варианты подписи описаны в комментариях внутри `Local.xcconfig.example`:
- **Без Apple Developer account** — локальная сборка с Automatic signing.
- **С аккаунтом** — Manual signing и ваш `DEVELOPMENT_TEAM`.

## Сборка и запуск GUI

Локально приложение собирается и запускается **только Release** (production). Схема `equinox` закреплена за Release, поэтому Cmd+R в Xcode и `./run.sh` дают одинаковый билд.

```bash
./run.sh
```

Скрипт:
1. Собирает `equinox` (Release) в `build/DerivedData`.
2. При отсутствии bridge-бинаря — собирает `equinox-bridge`.
3. При отсутствии `mcp/dist/server.js` — запускает `./scripts/build-mcp.sh`.
4. Перезапускает equinox (`pkill` + `open`).

После запуска ищите иконку в строке меню. Приложение покажет календарную панель с месячной сеткой и agenda; настройки открываются из меню панели или системного окна Settings.

### Ручная сборка через xcodebuild

```bash
xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

Артефакт: `build/DerivedData/Build/Products/Release/equinox.app`

## Тесты

### Swift (XCTest)

```bash
xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  test
```

Тесты Core и Services — в `equinoxTests/`. Живой EventKit в unit-тестах не используется.

### MCP (TypeScript)

```bash
cd mcp && npm install
cd mcp && npm run build   # tsc -p tsconfig.json, strict: true
cd mcp && npm test        # vitest run
```

## Calendar MCP

MCP даёт AI-клиентам доступ к календарю macOS через Equinox. Основной путь использует запущенное `equinox.app` как локальный proxy к `equinox-bridge`, чтобы macOS применяла Calendar permission самого приложения. Если приложение не запущено, MCP пробует прямой fallback на bridge.

MCP-сервер предоставляет:

- доступ: `get_calendar_access_status`, `request_calendar_access`;
- календарь и события: `list_calendars`, `list_events`, `get_event`, `create_event`, `update_event`, `delete_event`;
- аналитику: `analyze_schedule`, `find_conflicts`, `find_free_time`;
- Plaud read-only: `get_plaud_status`, `list_plaud_recordings`;
- prompts: `daily_agenda`, `weekly_calendar_review`;
- resources: `equinox://docs/calendar`, `equinox://schema/event`.

### Полная сборка bridge + MCP

```bash
./scripts/build-mcp.sh
```

Скрипт:
1. Генерирует список имён MCP-инструментов (`scripts/gen-mcp-tool-names.sh`).
2. Собирает `equinox-bridge` (Release).
3. Собирает и тестирует MCP (`npm install`, `npm run build`, `npm test`).

Артефакты:
- Bridge: `build/DerivedData/Build/Products/Release/equinox-bridge`
- MCP: `mcp/dist/server.js`

### Настройка клиентов

**Через GUI (рекомендуется):**

1. equinox → Settings → MCP.
2. Проверьте готовность Node.js, bridge и MCP-сервера.
3. Включите «Auto-configure Cursor and Claude» — equinox запишет сервер `equinox-calendar` в конфиги Cursor и Claude Desktop.
4. Для Codex скопируйте TOML-сниппет в `~/.codex/config.toml`.
5. Перезапустите клиент или перезагрузите MCP-серверы и оставьте `equinox.app` запущенным для основного TCC-safe пути.

**Вручную** — JSON-конфиг с `command`, `args` и `env.EQUINOX_BRIDGE_PATH`; пример генерируется на вкладке MCP.

### Разработка MCP

```bash
cd mcp && npm run dev   # tsx src/server.ts
```

### TCC

У `equinox.app` и прямого запуска `equinox-bridge` **раздельные** Calendar-разрешения TCC. Когда MCP идёт через app bridge proxy, используется разрешение приложения. При прямом fallback на bridge macOS может показать отдельный системный диалог или заблокировать доступ, если клиент не имеет нужного entitlement.

Подробности — в [mcp/MCP.md](mcp/MCP.md) и [bridge/BRIDGE.md](bridge/BRIDGE.md).

## Сборка только bridge

```bash
xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox-bridge \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

Переменная `EQUINOX_BRIDGE_PATH` указывает MCP на бинарь, если он не в DerivedData по умолчанию.

## Нотаризация и распространение

Ручной процесс через Xcode:

1. Product → Archive.
2. В Organizer: Distribute App → загрузка Developer ID на нотаризацию.
3. Дождитесь успешной нотаризации.
4. Экспортируйте нотаризованное приложение для распространения.

### Ресурсы Apple

- [Notarizing Your App Before Distribution](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution?language=objc)
- [Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/customizing_the_notarization_workflow?language=objc)
- [Resolving Common Notarization Issues](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/resolving_common_notarization_issues?language=objc)

## См. также

- [README.md](README.md) — обзор возможностей
- [ARCHITECTURE.md](ARCHITECTURE.md) — архитектура и различия app vs bridge
- [AGENTS.md](AGENTS.md) — правила для разработчиков и AI-агентов
