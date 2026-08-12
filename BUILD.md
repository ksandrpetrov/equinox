# Сборка и запуск

Руководство по локальной разработке, запуску, тестированию и release-сборке equinox.

## Что собирается

В репозитории два Xcode target:

| Часть | Что даёт пользователю |
|-------|------------------------|
| `equinox.app` | menu bar календарь: месячная сетка, agenda, создание/удаление событий, RSVP, join meeting, настройки, Plaud-интеграция |
| `equinoxTests` | XCTest для чистой логики и сервисных контрактов без живого EventKit |

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

### Swift (XCTest)

```bash
. scripts/xcodebuild-local-settings.sh
load_xcodebuild_local_settings Local.xcconfig

xcodebuild \
  -project equinox.xcodeproj \
  -scheme equinox \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  test \
  "${XCODEBUILD_LOCAL_SETTINGS[@]}"
```

Тесты Core и Services — в `equinoxTests/`. Живой EventKit в unit-тестах не используется.

## Локализация

Базовый язык — английский: строки задаются прямо в коде через `String(localized:comment:)`. Перевод один — русский, в `equinox/ru.lproj/Localizable.strings` (плюс `InfoPlist.strings` для описаний доступа).

Чтобы добавить или обновить переводы:

1. Откройте проект в Xcode и выберите **Editor → Export For Localization…** — получится `.xliff` на каждую локаль.
2. Отредактируйте `.xliff` (например, в Counterparts Lite).
3. Вернитесь в Xcode и выберите **Editor → Import Localizations…**

Экспортированные `.xliff` — промежуточный артефакт, в репозиторий они не коммитятся; источник правды — `.strings` в `ru.lproj`.

## Ресурсы приложения

`AppIcon` и `AppLogo` в `equinox/Images.xcassets` не рисуются вручную, а генерируются из `scripts/assets/equinox-mark.png`:

```bash
swift scripts/regenerate-design-assets.swift
```

Скрипт перезаписывает все размеры appiconset, оба масштаба `AppLogo` и его `Contents.json`. Запускайте его после замены исходного марка, а не правьте PNG'и по отдельности.

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
- [ARCHITECTURE.md](ARCHITECTURE.md) — архитектура приложения
- [AGENTS.md](AGENTS.md) — правила для разработчиков и AI-агентов
