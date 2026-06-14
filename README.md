# equinox

equinox — календарь для macOS в строке меню. Он показывает месячную сетку и agenda поверх рабочего стола, помогает быстро создать или удалить событие, ответить на приглашение, открыть ссылку на встречу и найти связанную запись Plaud для прошедшей встречи. В проект также входит **Calendar MCP**: локальный сервер, через который AI-клиенты вроде Cursor, Codex и Claude могут читать, анализировать и по запросу менять системный календарь macOS.

## Что умеет приложение

### Календарь и панель

- **Месячная сетка** — компактный календарь в menu bar с выбранным днём, сегодняшней датой, границами месяца, event dots, неделями и подсветкой выбранных дней недели.
- **Agenda** — список событий выбранного дня или ближайших дней; можно показывать/скрывать пустые дни и локации.
- **Навигация** — переход по месяцам, возврат к сегодняшнему дню, выбор дня в сетке, deep link `equinox://date/yyyy-MM-dd`.
- **Создание событий** — title, дата/время, all-day, календарь, location, URL, notes, повтор (daily/weekly/biweekly/monthly/yearly) и alert.
- **Просмотр и удаление** — карточка события показывает время, календарь, локацию, заметки, join URL, RSVP-статус и Plaud-действия; удаление доступно только для writable календарей.
- **RSVP** — ответ на приглашение: accept / maybe / decline прямо из карточки события.
- **Фильтрация календарей** — выбор календарей по источникам, с учётом read-only календарей.
- **Popover или pinned panel** — панель открывается по клику на menu bar icon или закрепляется как плавающее окно; состояние pinned восстанавливается после перезапуска.
- **Keyboard-first действия** — глобальный shortcut, `T` для Today, `Cmd+N` для нового события, `P` для pin/unpin, `Cmd+,` для настроек.
- **Join meeting** — распознаёт Zoom, Microsoft Teams и Amazon Chime в URL, location и notes; в GUI может открывать нативное приложение, если оно установлено.

Редактирование существующего события в GUI намеренно не поддерживается. Для частичного обновления события есть MCP-инструмент `update_event`.

### Оформление и menu bar

- **Настраиваемая иконка menu bar** — дата, день недели, месяц, часы или скрытая иконка; индикатор встречи показывает, что встреча скоро начнётся.
- **Темы и размеры** — light / dark / system, glass или solid фон, размеры панели Small / Medium / Large.
- **Настройки отображения** — event dots, номера недель, локации, пустые дни в agenda, границы месяца и подсветка выбранных дней недели.
- **Launch at login** — автозапуск при входе в систему.
- **Privacy** — отдельная вкладка статуса доступа к календарю macOS.
- **Локализация** — английский и русский (`ru.lproj`, `_translations/`).

### Plaud (опционально)

- **OAuth-подключение** — вход и выход из Plaud через вкладку Plaud в Settings; токены хранятся локально в Keychain.
- **Каталог записей** — Equinox может обновлять локальный каталог Plaud-записей и показывать статус кэша.
- **Автоматический match** — сопоставление прошедших календарных встреч с Plaud-записями по времени и метаданным.
- **Ручная привязка** — можно вставить ссылку `https://web.plaud.ai/file/...` в карточке прошедшего события.
- **Открытие записи** — если match найден, карточка события показывает кнопку **Open in Plaud**.

### Calendar MCP (опционально)

- **13 инструментов** — доступ к календарю, список календарей, чтение/создание/обновление/удаление событий, анализ загрузки, поиск конфликтов, поиск свободного времени и read-only доступ к локальному кэшу Plaud.
- **Prompts и resources** — готовые шаблоны `daily_agenda`, `weekly_calendar_review`, Markdown-обзор `equinox://docs/calendar` и JSON Schema `equinox://schema/event`.
- **Plaud в событиях** — `list_events` и `get_event` могут автоматически добавлять `hasPlaudRecording` и `plaudRecording` из локального кэша Equinox.
- **Автонастройка** — вкладка MCP в Settings может записать конфиг в Cursor и Claude Desktop; для Codex показывает TOML-сниппет.
- **Поддерживаемые клиенты** — Cursor, Codex, Claude Desktop.
- **Безопасный путь доступа** — основной MCP-путь идёт через запущенный `equinox.app`, чтобы macOS применяла Calendar permission Equinox; прямой fallback на `equinox-bridge` остаётся для headless-сценариев.

### Настройки

Settings содержит вкладки: General, Calendars, Appearance, Privacy, Shortcuts, MCP, Plaud, About. В настройках можно управлять автозапуском, первым днём недели, количеством дней в agenda, pin-поведением, высотой agenda, выбранными календарями, внешним видом, shortcut, MCP-подключением и Plaud-интеграцией.

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

`equinox-bridge` — headless CLI (JSON ↔ EventKit), используемый MCP-сервером. MCP сначала пытается обратиться к локальному app bridge proxy внутри запущенного `equinox.app`; если приложение не запущено, используется прямой запуск bridge.

```bash
./scripts/build-mcp.sh
```

**Настройка клиентов:**

1. Откройте equinox → Settings → MCP.
2. Убедитесь, что bridge, Node.js и MCP-сервер в статусе «готов».
3. Включите «Auto-configure Cursor and Claude» или скопируйте JSON / TOML-сниппет вручную.
4. Перезапустите MCP-клиент или перезагрузите его MCP-серверы.
5. Держите `equinox.app` запущенным для основного app bridge proxy пути; прямой fallback на `equinox-bridge` может потребовать отдельное Calendar-разрешение macOS.

Подробности — в [mcp/MCP.md](mcp/MCP.md) и [bridge/BRIDGE.md](bridge/BRIDGE.md).

## Архитектура

equinox — гибрид **AppKit-оболочки и SwiftUI-панелей**. Бизнес-логика дат, сетки, раскладки событий, RSVP и join URL живёт в `Core/`. Доступ к EventKit идёт через `CalendarStore` (GUI) и `EventKitBridge` (CLI). UI не обращается к `EKEventStore` напрямую; MCP работает через app bridge proxy или `equinox-bridge`.

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

Подробная схема слоёв, потоков данных, ограничений GUI/MCP и подсистемы Plaud — в [ARCHITECTURE.md](ARCHITECTURE.md).

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
