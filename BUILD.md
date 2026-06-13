### Подпись кода (Code Signing)

Проект использует файл `Local.xcconfig` для настройки подписи кода, чтобы данные о подписи не попадали в репозиторий (`project.pbxproj`). Скопируйте `Local.xcconfig.example` в `Local.xcconfig`. Для локальной разработки можно оставить значения по умолчанию. Подробности — в комментариях внутри файла.

```
cp Local.xcconfig.example Local.xcconfig
```

### Сборка и запуск локально

Мы собираем и запускаем только одну конфигурацию: **Release** (production). Общая схема `equinox` закреплена за `Release` для всех действий, поэтому сборка из Xcode (Cmd+R) или из командной строки всегда даёт одинаковый production-билд.

Чтобы собрать и запустить за один шаг:

```
./run.sh
```

Команда собирает `Release` в `build/DerivedData` и открывает приложение. equinox — это menu bar приложение, поэтому после запуска ищите его иконку в строке меню.

### Calendar MCP (Cursor, Codex, Claude)

Чтобы управлять календарями и анализировать их из Cursor, Codex или Claude Desktop через EventKit:

```
./scripts/build-mcp.sh
```

Команда собирает `equinox-bridge` и TypeScript MCP-сервер в `mcp/`. Включите сервер `equinox-calendar` из [`.cursor/mcp.json`](.cursor/mcp.json), вставьте JSON в конфиг Claude Desktop или добавьте TOML-сниппет из Настроек equinox → MCP в `~/.codex/config.toml`. При первом использовании macOS запросит доступ к календарю для `equinox-bridge` (отдельно от `equinox.app`).

Для разработки:

```
cd mcp && npm run dev
cd mcp && npm test
```

### Сборка и нотаризация

1. В Xcode выберите Product > Archive.

2. В Xcode Organizer выберите Distribute App и пройдите процесс
   загрузки приложения Developer ID на нотаризацию. Значения по умолчанию
   обычно подходят.

3. Дождитесь уведомления о том, что приложение успешно нотаризовано.

4. Экспортируйте нотаризованное приложение для распространения.

### Ресурсы

[Notarizing Your App Before Distribution](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution?language=objc)

[Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/customizing_the_notarization_workflow?language=objc)

[Resolving Common Notarization Issues](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution/resolving_common_notarization_issues?language=objc)
