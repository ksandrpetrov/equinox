# Сборка и запуск

Руководство по локальной разработке, запуску, тестированию и release-сборке equinox.

## Что собирается

В репозитории пять Xcode targets:

| Часть | Что даёт пользователю |
|-------|------------------------|
| `equinox.app` | menu bar календарь: месячная сетка, agenda, создание/удаление событий, read-only RSVP-статус, join meeting, настройки |
| `EquinoxKit` | Код приложения без `@main`, локализация и ресурсы |
| `equinoxTests` | XCTest библиотеки без запуска приложения |
| `equinoxGraphicsHost` | Минимальный AppKit-host без AppDelegate и доступа к календарю |
| `equinoxGraphicsTests` | Рендеры компонентов, компоновка экранов и ресурсы |

## Требования

- Mac на **Apple Silicon** (arm64). `run.sh` и `scripts/require-arm64.sh` завершаются с ошибкой на Intel.
- macOS **26.0** или новее.
- **Xcode** — для сборки `equinox` и `equinoxTests`.

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

`./run.sh` передаёт signing-настройки из `Local.xcconfig` в `xcodebuild` как command-line overrides. Это важно: target-level настройки Xcode имеют более высокий приоритет, чем base xcconfig, и без override локальная сборка может выбрать устаревший или отозванный сертификат из Keychain.

## Сборка и запуск GUI

Локально приложение собирается и запускается **только Release** (production). Для запуска из Xcode убедитесь, что signing-настройки target соответствуют вашему `Local.xcconfig`; `./run.sh` делает это автоматически через command-line overrides.

```bash
./run.sh
```

Скрипт:
1. Собирает `equinox` (Release) в `build/DerivedData`.
2. Проверяет наличие `equinox.app`.
3. Перезапускает equinox (`pkill` + `open`).

После запуска ищите иконку в строке меню. Приложение покажет календарную панель с месячной сеткой и agenda; настройки открываются из меню панели или системного окна Settings.

### Ручная сборка через xcodebuild

```bash
. scripts/xcodebuild-local-settings.sh
load_xcodebuild_local_settings Local.xcconfig

xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build \
  "${XCODEBUILD_LOCAL_SETTINGS[@]}"
```

Артефакт: `build/DerivedData/Build/Products/Release/equinox.app`

## Тесты

```bash
./scripts/test.sh
```

Команда запускает обычные и графические XCTest в Debug и Release с покрытием.
`equinox.app` не запускается. Графическому host нужна активная графическая сессия
macOS. Тесты календарных сценариев используют подставной `CalendarEventStore`;
проверки адаптера создают несохранённые объекты EventKit, без запроса доступа,
выборки пользовательских событий, сохранения или удаления.

```bash
./scripts/test.sh --configuration Debug --suite unit
./scripts/test.sh --configuration Release --suite graphics
./scripts/test.sh --configuration Debug --suite unit \
  --filter equinoxTests/LoadingIndicatorControllerTests
```

Логи, `.xcresult`, JSON-сводки и покрытие сохраняются в отдельной папке каждого
запуска под `build/Tests/results/`. Нулевое число тестов, ошибка или пропуск
завершают команду с ошибкой. Покрытие отражает исполненные строки, а не полноту
бизнес-сценариев; рендеры не заменяют живую проверку EventKit и взаимодействий.

Пути можно переопределить переменными `EQUINOX_TEST_DERIVED_DATA` и
`EQUINOX_PACKAGE_CACHE`. По умолчанию checkout пакетов общий с `run.sh`:
`build/DerivedData/SourcePackages`. `Package.resolved` включён в Git; используется
закреплённая версия KeyboardShortcuts. Первому запуску требуется сеть для загрузки
пакета, последующие используют кэш. Обновление зависимостей выполняется отдельной
задачей с ревью изменения lock-файла.

Для запуска из Xcode доступны схемы `equinoxTests` и `equinoxGraphicsTests`.
Release-тестам нужен `ENABLE_TESTABILITY=YES` (скрипт передаёт его автоматически).
Подпись для тестовой сборки отключена; GUI собирается отдельно через `run.sh`
с настройками `Local.xcconfig`.

Старый `scripts/test-offline.py` удалён: ручная компиляция `swiftc` и специальная
подстановка ресурсов больше не нужны. Исторические отчёты `AUDIT.md`,
`DESIGN-AUDIT.md`, `OFFLINE-TEST-REPORT.md` описывают прежние прогоны; текущий итог —
`REFACTOR-REPORT.md`.

## Локализация

Базовый язык — английский: строки задаются через `String(localized:bundle:comment:)` с `bundle: .equinox`. Русский перевод хранится в `equinox/ru.lproj/Localizable.strings`, формы множественного числа — в `Localizable.stringsdict` соответствующей локали, а описания доступа — в `InfoPlist.strings`.

Чтобы добавить или обновить переводы:

1. Откройте проект в Xcode и выберите **Editor → Export For Localization…** — получится `.xliff` на каждую локаль.
2. Отредактируйте `.xliff` (например, в Counterparts Lite).
3. Вернитесь в Xcode и выберите **Editor → Import Localizations…**

Экспортированные `.xliff` — промежуточный артефакт, в репозиторий они не коммитятся; источник правды — файлы локализации в `ru.lproj`.

## Ресурсы приложения

`EquinoxKit` владеет локализацией и графическими ресурсами. `Bundle.equinox`
находит framework через класс-маркер, поэтому одинаково работает в GUI и XCTest.
Именованные `Color` и `Image` используют этот bundle явно. Версия приложения и
описания TCC остаются в bundle `equinox.app`.


`AppIcon` и `AppLogo` в `equinox/Images.xcassets` генерируются из геометрического исходника `drawEquinoxMark` в Swift-скрипте (он также сохраняет `scripts/assets/equinox-mark.png`):

```bash
swift scripts/regenerate-design-assets.swift
```

Скрипт перезаписывает все размеры appiconset, оба масштаба `AppLogo` и его `Contents.json`. Геометрический исходник знака находится в `drawEquinoxMark` этого скрипта; PNG знака, AppIcon и AppLogo генерируются вместе. Не правьте PNG по отдельности.

## Нотаризация и распространение

### Mac App Store

App Sandbox включён для target `equinox` в Debug и Release. Файл
`equinox/equinox.entitlements` содержит `com.apple.security.app-sandbox = true`
и `com.apple.security.personal-information.calendars = true` для доступа к EventKit.
Разрешение пользователя на полный доступ к календарям по-прежнему требуется.

После изменения entitlements создайте новый архив через **Product → Archive**
и в Organizer выберите **Distribute App → App Store Connect**. Уже созданный
архив или `.pkg` не получает новые entitlements автоматически.

Перед загрузкой проверьте entitlements в подписи приложения из нового архива
(подставьте путь к своему `.xcarchive`):

```bash
codesign -d --entitlements - /path/to/equinox.xcarchive/Products/Applications/equinox.app
```

Оба ключа должны иметь Boolean-значение `true`. После включения Sandbox
проверьте доступ к календарям и сохранение настроек при обновлении существующей
установки. Подробнее: [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox).

### Developer ID

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
- [ARCHITECTURE.md](ARCHITECTURE.md) — архитектура приложения
- [AGENTS.md](AGENTS.md) — правила для разработчиков и AI-агентов
