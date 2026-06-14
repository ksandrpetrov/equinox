# equinox

Календарь для macOS в строке меню (menu bar), написанный на Swift/SwiftUI + AppKit. Показывает месячную сетку и agenda прямо из menu bar, умеет создавать и удалять события, отвечать на приглашения (RSVP) и опционально связывать встречи с записями Plaud. Включает Calendar MCP — сервер для управления и анализа календарей из AI-агентов (Cursor, Codex, Claude).

## Возможности

### Календарь и панель

- **Месячная сетка и agenda** — просмотр месяца и списка событий выбранного дня.
- **Навигация** — переход между месяцами, go-to-date, выбор дня, deep link `equinox://date/yyyy-MM-dd`.
- **Работа с событиями** — создание, просмотр и удаление (редактирование в GUI намеренно не поддерживается — см. [ARCHITECTURE.md](ARCHITECTURE.md)).
- **RSVP** — ответ на приглашения (принять / отклонить / возможно) из карточки события.
- **Фильтрация календарей** — выбор того, какие календари показывать.
- **Два режима панели** — popover по клику на иконку или закреплённая плавающая панель (pinned); состояние восстанавливается после перезапуска.
- **Превью при наведении** — опциональный popover со списком событий дня при hover на ячейке сетки.
- **Join meeting** — распознавание ссылок Zoom / Teams / Chime, открытие в вебе или нативном приложении.
- **Глобальный шорткат** — открытие панели по горячей клавише (MASShortcut).

### Оформление и menu bar

- **Настраиваемая иконка menu bar** — дата, день недели или скрытая иконка; индикатор текущей встречи (meeting indicator).
- **Темы и размеры** — light / dark / system, glass или solid фон, размеры панели S / M / L.
- **Launch at login** — автозапуск при входе в систему.
- **Локализация** — английский и русский (`ru.lproj`, `_translations/`).

### Plaud (опционально)

- **OAuth-подключение** — настройка через вкладку Plaud в Settings.
- **Автоматический match** — сопоставление прошлых встреч с записями Plaud.
- **Ручная привязка** — линковка записи к событию из карточки события.

### Calendar MCP (опционально)

- **11 инструментов** — CRUD событий, список календарей, аналитика расписания через `equinox-bridge`.
- **Автонастройка** — вкладка MCP в Settings может записать конфиг в Cursor и Claude Desktop; для Codex — TOML-сниппет.
- **Поддерживаемые клиенты** — Cursor, Codex, Claude Desktop.

## Требования

| Компонент | Требование |
|-----------|------------|
| Платформа | Mac на **Apple Silicon** (M1 или новее); Intel не поддерживается |
| macOS | **26.0** или новее |
| Сборка GUI | Xcode |
| MCP | Node.js (для `mcp/`) |
| Доступ к календарю | EventKit full-access API; у `equinox.app` и `equinox-bridge` **раздельные** разрешения TCC |

## Быстрый старт

```bash
cp Local.xcconfig.example Local.xcconfig
./run.sh
```

`./run.sh` собирает приложение в **Release**, при необходимости — `equinox-bridge` и MCP-сервер, затем запускает equinox. После старта ищите иконку в строке меню.

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

Полная сборка bridge + MCP + тесты:

```bash
./scripts/build-mcp.sh
```

## MCP / bridge

`equinox-bridge` — headless CLI (JSON ↔ EventKit), используется MCP-сервером. Сборка:

```bash
./scripts/build-mcp.sh
```

**Настройка клиентов:**

1. Откройте equinox → Settings → MCP.
2. Убедитесь, что bridge, Node.js и MCP-сервер в статусе «готов».
3. Включите «Auto-configure Cursor and Claude» или скопируйте JSON / TOML-сниппет вручную.
4. При первом использовании macOS запросит доступ к календарю для `equinox-bridge` (отдельно от `equinox.app`).

Подробности — в [mcp/MCP.md](mcp/MCP.md) и [bridge/BRIDGE.md](bridge/BRIDGE.md).

## Архитектура

equinox — гибрид **AppKit-оболочки и SwiftUI-панелей**. Бизнес-логика живёт в `Core/`, доступ к EventKit — строго через два адаптера: `CalendarStore` (GUI) и `EventKitBridge` (CLI). UI не обращается к `EKEventStore` напрямую; MCP — только через bridge.

```
equinox/        — приложение в строке меню (Swift/SwiftUI + AppKit)
  App/            — жизненный цикл, AppState, PlaudCoordinator, Constants
  Core/           — чистая логика (тестируемая)
  Services/       — EventKit, Plaud, настройки, платформенные хелперы
  UI/             — SwiftUI-вью и design tokens
bridge/         — CLI equinox-bridge (JSON ↔ EventKit)
mcp/            — TypeScript MCP-сервер
equinoxTests/   — XCTest
scripts/        — run.sh, build-mcp.sh, require-arm64.sh
```

Подробная схема слоёв, потоков данных и подсистемы Plaud — в [ARCHITECTURE.md](ARCHITECTURE.md).

## Настройки

Вкладки Settings (`SettingsTab`): General, Calendars, Appearance, Privacy, Shortcuts, MCP, Plaud, About.

## Документация

| Документ | Назначение |
|----------|------------|
| [BUILD.md](BUILD.md) | Сборка, запуск, MCP, тесты, нотаризация |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Слои, потоки данных, Plaud, различия app vs bridge |
| [bridge/BRIDGE.md](bridge/BRIDGE.md) | JSON-протокол equinox-bridge |
| [mcp/MCP.md](mcp/MCP.md) | Справочник инструментов MCP |
| [AGENTS.md](AGENTS.md) | Правила для AI-агентов и разработчиков |

## Лицензия

Проект распространяется по лицензии MIT. Полный текст — в [LICENSE.txt](LICENSE.txt).
