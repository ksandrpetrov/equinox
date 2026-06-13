# equinox

Календарь для macOS в строке меню (menu bar), написанный на Swift/SwiftUI + AppKit. Показывает месячную сетку и agenda прямо из menu bar, умеет создавать и удалять события, а также включает опциональный Calendar MCP — сервер для управления и анализа календарей из AI-агентов (Cursor, Codex, Claude).

## Возможности

- **Месячная сетка и agenda** — просмотр месяца и списка событий выбранного дня.
- **Навигация** — переход между месяцами, go-to-date, выбор дня, deep link `equinox://date/yyyy-MM-dd`.
- **Работа с событиями** — создание, просмотр и удаление событий (редактирование в GUI намеренно не поддерживается — см. [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Фильтрация календарей** — выбор того, какие календари показывать.
- **Два режима панели** — popover по клику на иконку или закреплённая плавающая панель (pinned), состояние восстанавливается после перезапуска.
- **Настраиваемая иконка menu bar** — дата, день недели или скрытая иконка; индикатор встречи (meeting indicator).
- **Join meeting** — распознавание ссылок Zoom / Teams / Chime, открытие в вебе или нативном приложении.
- **Глобальный шорткат** — открытие панели по горячей клавише (MASShortcut).
- **Оформление** — темы light / dark / system, glass или solid фон, размеры панели S / M / L.
- **Launch at login** — автозапуск при входе в систему.
- **Локализация** — английский и русский.
- **Calendar MCP (опционально)** — 11 инструментов для доступа к календарю и аналитики расписания через `equinox-bridge`.

## Требования

- Mac на **Apple Silicon** (M1 или новее).
- macOS **26.0** или новее.
- Xcode (для локальной сборки).
- Доступ к Календарю (EventKit, full-access API). У `equinox.app` и `equinox-bridge` **раздельные** разрешения TCC.

## Быстрый старт

```bash
cp Local.xcconfig.example Local.xcconfig
./run.sh
```

Локальная сборка и запуск выполняются **только в конфигурации Release**. После запуска ищите иконку equinox в строке меню.

`Local.xcconfig` хранит настройки подписи кода вне репозитория и добавлен в `.gitignore` — не коммитьте его. Подробнее — в [BUILD.md](BUILD.md).

## Тесты

Swift unit-тесты (XCTest):

```bash
xcodebuild -project equinox.xcodeproj -scheme equinox -configuration Debug \
  -derivedDataPath build/DerivedData test
```

MCP (TypeScript):

```bash
cd mcp && npm install && npm run build && npm test
```

## MCP / bridge

Сборка `equinox-bridge` и TypeScript MCP-сервера одной командой:

```bash
./scripts/build-mcp.sh
```

Включите сервер `equinox-calendar` из [`.cursor/mcp.json`](.cursor/mcp.json), вставьте JSON в конфиг Claude Desktop или добавьте TOML-сниппет из Настроек equinox → MCP в `~/.codex/config.toml`. При первом использовании macOS запросит доступ к календарю для `equinox-bridge` (отдельно от `equinox.app`).

Подробности — в [mcp/MCP.md](mcp/MCP.md) и [bridge/BRIDGE.md](bridge/BRIDGE.md).

## Архитектура

equinox — гибрид **AppKit-оболочки и SwiftUI-панелей**. Бизнес-логика живёт в `Core/`, а доступ к EventKit идёт строго через два адаптера: `CalendarStore` (GUI) и `EventKitBridge` (CLI). UI никогда не обращается к `EKEventStore` напрямую, а MCP — к EventKit напрямую.

```
equinox/   — приложение в строке меню (Swift/SwiftUI + AppKit)
  App/       — жизненный цикл, AppState, Constants
  Core/      — чистая логика (тестируемая)
  Services/  — EventKit, настройки, платформенные хелперы
  UI/        — SwiftUI-вью и design tokens
bridge/    — CLI equinox-bridge (JSON ↔ EventKit)
mcp/       — TypeScript MCP-сервер
equinoxTests/ — XCTest
scripts/   — build-mcp.sh
```

Подробная схема слоёв и потоков данных — в [ARCHITECTURE.md](ARCHITECTURE.md).

## Документация

| Документ | Назначение |
|----------|------------|
| [AGENTS.md](AGENTS.md) | Правила для AI-агентов и разработчиков |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Схема слоёв и потоки данных |
| [BUILD.md](BUILD.md) | Сборка, запуск, настройка MCP, нотаризация |
| [bridge/BRIDGE.md](bridge/BRIDGE.md) | JSON-протокол bridge |
| [mcp/MCP.md](mcp/MCP.md) | Справочник инструментов MCP |

## Лицензия

Проект распространяется по лицензии MIT. Полный текст и сведения об авторстве upstream-кода — в [LICENSE.txt](LICENSE.txt).
