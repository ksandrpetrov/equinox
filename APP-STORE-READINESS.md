# Mac App Store readiness — 2026-10-23

## Итог

В магазине опубликована **1.0.2**: версия подтверждена 23 октября через
публичный Apple lookup для приложения `6806746414`; дата выпуска —
9 октября 2026, 19:13:53 UTC. Политика конфиденциальности, поддержка и App Privacy опубликованы.

Хотфикс **1.0.3 (10)** загружен, успешно обработан Apple и отправлен на
App Review **23 октября 2026 в 21:01 MSK**. Статус: **Waiting for Review**.
Настроен автоматический выпуск сразу для всех пользователей после одобрения,
без phased release. Обновление ещё не опубликовано.
[Заявка в App Store Connect](https://appstoreconnect.apple.com/apps/6806746414/distribution/reviewsubmissions/details/99b834e7-3152-4d9c-a5c9-dab3550d4d48).
Метаданные: `docs/app-store/metadata-1.0.3.json`.

## Обновление 1.0.3 — 2026-10-23

Закреплённая панель следует за значком строки меню при запуске, пока пользователь
не переместит её вручную. Повторное открытие календаря возвращает к сегодняшнему
дню, сохраняя открытую форму события. Окно настроек получает корректный исходный
размер до присоединения hosted content; устранены предупреждения конфликтующих
constraints. Настройки темы безопасно обрабатывают отсутствие NSApplication.

Аудит тестов завершён: 394 unit + 37 graphics; 25 полных повторов в Debug и Release
дали 21 550 успешных выполнений. Unit Thread Sanitizer — ещё 788 выполнений.
Release собран и запущен. Все 190 проверенных входных файлов совпали с финальными
хешами перед подготовкой релиза. Подробности, мутационные результаты и ограничения:
[отчёт об аудите](docs/qa/2026-10-22-tests-audit.md).
Ручная проверка живого GUI после финальной сборки не выполнена: Mac был заблокирован.

- Все изменения приложения, тестов и материалов аудита опубликованы в `main`,
  исходный коммит архива: `1b6a59cca994c0d85180e5a27fc01cfedba04652`.
- Архив создан с `MARKETING_VERSION=1.0.3`, `CURRENT_PROJECT_VERSION=10` и
  релизными параметрами подписи через командную строку. `Local.xcconfig` и signing
  в `project.pbxproj` не менялись. Первый архив с локальной ad-hoc подписью сохранён
  отдельно и не использован для экспорта/загрузки.
- Проверен распакованный `.pkg`: подписи app, EquinoxKit и resource bundle
  совпадают с сертификатом действующего provisioning profile; Sandbox и calendar
  entitlement включены, `get-task-allow` отсутствует. Подтверждены версия/номер,
  arm64, privacy manifests, локализация и подпись установочного пакета.
- Архивы: `build/Archives/equinox-1.0.3-10-2026-10-23.xcarchive` и
  `build/Archives/equinox-1.0.3-10-2026-10-23-distribution.xcarchive`.
  Готовый пакет: `build/TestFlight/2026-10-23-stability-hotfix/VerifiedExport/equinox.pkg`.
  В том же каталоге релиза сохранены `release-manifest.json`, `package-verification.json`,
  параметры экспорта и журналы. SHA-256 пакета:
  `aba291898b1f57ab3ee4faa2eb76caaeb6e68ed103ca31f8184028aa8754a38b`.
- После восстановления входа Apple ID в Xcode загрузка завершилась
  **23 октября в 20:55:58 MSK**. App Store Connect подтвердил
  **Ready to Submit** для сборки (10); Build ID:
  `662982cc-cbf2-4f58-b753-15451801098d`.
- Сборка (10) выбрана для версии 1.0.3. Сохранены RU/EN release notes и Notes for
  Review; прежние описания, рекламные тексты, скриншоты и контакты App Review
  сохранены. Выбраны автоматический выпуск и обновление сразу для всех пользователей.
- Apple подтвердила **Waiting for Review**, дата отправки в UI —
  **23 октября, 21:01 MSK**; Submission ID:
  `99b834e7-3152-4d9c-a5c9-dab3550d4d48`.
  Подтверждения в каталоге релиза: `waiting-for-review.jpg` и
  `waiting-for-review.txt`. Журнал успешной загрузки:
  `upload-restored-account.log`. До одобрения App Review публичной версией
  остаётся 1.0.2; дополнительный ручной выпуск после одобрения не требуется.

## Обновление 1.0.2 — 2026-10-09

В заголовок левой панели события добавлена кнопка закрытия. Она закрывает только
сведения события или форму создания, оставляя календарь открытым. Используются
существующие `PanelIconButton`, `SizeMetrics` и `AppState.dismissEventDrawer()`.
Во время сохранения/удаления закрытие заблокировано; Escape и стрелка на границе сохранены.

- `./scripts/test.sh`: 408 unit + 26 graphics в каждой из Debug и Release,
  868 выполнений, 0 ошибок и пропусков. Результаты: `build/Tests/results/run-fdEAIA/`.
  Новый тест нажимает крестик в просмотре и создании события, в обоих режимах окна
  и размерах S/M/L, проверяя сохранение открытого календаря и выбранного дня.
- `./run.sh`: Release собран и запущен. В живом приложении проверено закрытие
  сведений того же события, что в сообщении пользователя, в pinned/unpinned режимах;
  Escape закрывает форму создания. Закрепление восстановлено. Полная ручная
  проверка всех настроек не выполнялась; размеры, темы, фоны и settings tabs
  покрыты существующими графическими тестами.
- Версия/номер переданы при архивировании через `MARKETING_VERSION=1.0.2`
  и `CURRENT_PROJECT_VERSION=9`; signing в проекте и `Local.xcconfig` не менялись.
  В экспортированном пакете проверены подписи app, framework и resource bundle
  против provisioning profile, Sandbox/calendar entitlements, отсутствие
  `get-task-allow`, arm64, privacy manifests и русский перевод новой кнопки.
- Архивы: `build/Archives/equinox-1.0.2-9-2026-10-09*.xcarchive`.
  Пакет, журналы, source patch, manifest и подтверждения UI:
  `build/TestFlight/2026-10-09-drawer-close/`.
  Метаданные: `docs/app-store/metadata-1.0.2.json`.
- Загрузка завершена **9 октября в 14:52:40 MSK**; Apple подтвердила
  **Ready to Submit**. Build ID: `3df1cd75-e2a3-44a1-b45d-bb04572034eb`.
  Версия со сборкой (9) отправлена на App Review в 14:56 MSK;
  Submission ID: `c2df387b-efd1-4b52-bc81-62ada4b252af`.
  Подтверждение: `build/TestFlight/2026-10-09-drawer-close/waiting-for-review.png`.
  Сохранены прежние описания, рекламные тексты, скриншоты и контакты App Review.

## Обновление 1.0.1 — 2026-10-08

Исправлено скрытие календаря при открытой боковой панели события. Значок menu bar
и глобальная горячая клавиша скрывают окно, сохраняя форму в памяти;
незакреплённое окно также скрывается при клике снаружи и переходе в другое приложение.
Отдельный sheet подтверждения удаления сохраняет защиту от скрытия.

- Проверки: 408 unit + 25 graphics в каждой из Debug и Release; 866 выполнений,
  0 ошибок и пропусков. Результаты: `build/Tests/results/run-rgTQbF/` (unit),
  `build/Tests/results/run-f4aAmF/` (graphics). Release запущен через `./run.sh`.
  Полный ручной UI-прогон не подтверждён из-за тайм-аутов Computer Use.
- Версия и номер переданы при архивировании через `MARKETING_VERSION=1.0.1`
  и `CURRENT_PROJECT_VERSION=8`. Signing в проекте и `Local.xcconfig` не менялись.
  Проверены сертификаты app, EquinoxKit и resource bundle против provisioning
  profile, Sandbox/calendar entitlements, отсутствие `get-task-allow`, arm64
  и оба privacy manifests.
- Загрузка завершена **8 октября в 21:08:49 MSK**. Apple подтвердила **Complete**
  и **Ready to Submit**. Build ID: `82e56a25-2d37-4cb1-9123-d159b1fd48c0`.
  Submission ID: `962163f2-bc7c-448d-a0fa-37038e8d936f`.
- Описания обновления на RU/EN и Notes for Review сохранены в
  `docs/app-store/metadata-1.0.1.json`. Существующие описания, скриншоты,
  контакты App Review и настройки распространения сохранены.
- Архивы: `build/Archives/equinox-1.0.1-8-2026-10-08*.xcarchive`.
  Пакет, журналы, source patch, manifest и подтверждение `waiting-for-review.jpg`:
  `build/TestFlight/2026-10-08-panel-dismiss/`.

## Исправление замечания App Review — 2026-10-04

Пункт `Quit Equinox` уже находился в меню «…» календарной панели. Добавлено нативное
меню у значка строки меню: правый клик или Control-клик открывает `Preferences`
и `Quit Equinox` (⌘Q). Выход доступен без открытия календаря, загрузки событий
или выдачи Calendar access. Подсказка значка объясняет правый клик на EN/RU.
Завершение использует `NSApplication.terminate`, включая существующий teardown.
По просьбе владельца убрано многоточие после «Настройки» в обоих меню
и справке по горячим клавишам; используется существующая строка `Preferences`.

Левый клик и глобальная горячая клавиша продолжают переключать панель;
после закрытия меню обработка левого клика восстанавливается. Сценарии pin/popover,
отображения событий и прежний пункт выхода в «…» сохраняются.

В `PanelPresentationStateTests` добавлена проверка доступного пункта Quit при
закрытой панели, штатного target/action и ⌘Q; обновлена проверка подсказки.
Исходное сообщение Apple и снимок страницы: `build/AppReview/2026-10-04/`.

Проверки исправления:

- `./scripts/test.sh`: 408 unit + 22 graphics в Debug и столько же в Release;
  860 выполнений, 0 ошибок, пропусков и runtime warnings.
  Результаты: `build/Tests/results/run-IY22IT/`.
- После удаления многоточия повторный Release unit-прогон: 408 passed,
  0 failed/skipped; `build/Tests/results/run-eiQTPe/`.
  Приложение пересобрано через `./run.sh`; подпись «Настройки» без многоточия
  подтверждена в живом меню «…». Журнал: `build/AppReview/2026-10-04/release-final.log`.
- `./run.sh`: Release успешно собран и запущен;
  журнал `build/AppReview/2026-10-04/release-run.log`.
- `codesign --verify --deep --strict`, `plutil -lint` русской локализации
  и `git diff --check` прошли.
- В живом Release выбран «Завершить работу Equinox» из меню «…»; отсутствие
  процесса после выхода подтверждено. Повторный `./run.sh` восстановил
  закреплённую панель. Журнал: `build/AppReview/2026-10-04/release-after-quit.log`.
- Новое меню проверено XCTest на доступность команд и их target/action.
  Сам правый/Control-клик по системному значку в живом приложении не подтверждён:
  Computer Use предоставляет окно панели, но не доступ к значку строки меню.

Подготовлена Release-сборка **1.0.0 (7)**; номер передан через
`CURRENT_PROJECT_VERSION=7` при архивировании. Signing в проекте и
`Local.xcconfig` не менялись. После локального экспорта пакет распакован и проверен:
подписи приложения, EquinoxKit и KeyboardShortcuts resource bundle совпадают
с сертификатом в provisioning profile; Sandbox и calendar entitlement включены,
`get-task-allow` отсутствует. Проверены arm64, версия/номер сборки, оба privacy
manifests, обновлённая русская локализация и подсказка в исполняемом файле.

Загрузка успешно завершена **4 октября в 07:58:08 MSK**. App Store Connect
подтвердил **Complete** для загрузки и **Ready to Submit** для сборки (7).
ID сборки: `3763cd09-4b7a-446b-9f65-fdd970b21667`.
В форме версии 1.0 сборка (6) заменена на (7); сохранены обновлённые Notes for Review
с пояснением исправления Guideline 4. Выполнены Update Review и Resubmit to App Review.
**В 08:05 MSK Apple подтвердила Waiting for Review** для сборки 1.0.0 (7).
Submission ID сохранился: `f75f9af9-2220-4f32-8868-5f6c73300258`.
Подтверждение: `build/TestFlight/2026-10-04-app-review/submitted-for-review.png`.
Автоматический выпуск после одобрения сохранён; отдельное сообщение Reply to App Review
не отправлялось — инструкция по выходу включена в Notes for Review новой заявки.
Архивы: `build/Archives/equinox-app-review-2026-10-04*.xcarchive`.
Пакет, параметры экспорта, проверка подписей, журналы и release manifest:
`build/TestFlight/2026-10-04-app-review/`. Снимок исходного diff:
`build/AppReview/2026-10-04/source.patch`.

## Находки и исправления

| Область | Результат | Основание |
|---|---|---|
| Privacy Policy / поддержка | Добавлены PRIVACY.md и SUPPORT.md на EN/RU, ссылки в Privacy/About; контакт — GitHub Issues | Guidelines 1.5, 5.1.1(i) |
| Calendar purpose string | Теперь описывает чтение, создание и удаление по действию пользователя; согласованы Info.plist, русский InfoPlist.strings и UI | 5.1.1(ii) |
| Required-reason API | PrivacyInfo.xcprivacy включён в app и EquinoxKit; UserDefaults CA92.1, systemUptime 35F9.1, tracking=false | Документация privacy manifest; отсутствие раньше не названо доказанным автоматическим отказом для macOS |
| Сторонний код / права | Полные MIT-тексты Equinox/Itsycal и KeyboardShortcuts 3.0.1 встроены; доступен просмотр из About | Условия MIT, 5.2 |
| Sandbox / EventKit | В архиве только app-sandbox и personal-information.calendars; EventKit остаётся в CalendarStore | 2.4.5(i) |
| Автозапуск / выход | По коду SMAppService включается пользователем; есть Quit, teardown таймеров и shortcut | 2.4.5(iii) |
| Код / обновления | В проверенных исходниках нет загрузки кода, собственного updater, shell-процессов, private API-вызовов или повышения привилегий | 2.4.5, 2.5 |
| Данные / платежи | Нет аккаунтов, аналитики, рекламы, backend, IAP или подписок. Первая версия бесплатная | 3.1, 5.1 |
| Поведение | Создание/удаление остаётся через AppState и CalendarStore, RSVP только чтение; редактирование событий не обещается | 2.1, 2.3 |

KeyboardShortcuts использует публичный RegisterEventHotKey и локальные UserDefaults.
Его версия и Package.resolved не изменены. Приложение не отправляет данные разработчику;
синхронизацией календарных аккаунтов занимается macOS, а открытые пользователем ссылки
передаются внешнему приложению. Эти различия отражены в политике.

## Выполненные проверки

- `./scripts/test.sh`: 376 unit + 16 graphics в Debug, столько же в Release; 784 выполнения, 0 ошибок, 0 пропусков.
- Результаты: `build/Tests/results/run-czYnmB/`. Новый тест проверяет встроенные manifest и лицензии, расширен тест русской локализации.
- `./run.sh`: Release build и запуск успешны; журнал `build/app-store-run.log`.
- Release archive: `build/AppStoreAudit/equinox.xcarchive`; журнал `build/app-store-archive.log`.
- В архиве проверены оба manifests, полные тексты обеих лицензий, русский TCC-ресурс, отсутствие XCTest bundles.
- `codesign --verify --deep --strict` для архива прошёл; sandbox и calendar entitlement присутствуют.
- Первоначальный архив **ad-hoc**, без TeamIdentifier, использовался только для локальной проверки. Затем создан и проверен distribution-пакет 1.0.0 (6), успешно обработанный Apple; подробности ниже.
- Графические тесты охватывают все settings tabs, состояния разрешений, панели и формы в разных размерах/темах. Вручную просмотрены тестовые рендеры новых ссылок About (light) и Privacy (dark); они помещаются. Это рендеры host, не живой GUI-прогон.
- Полный живой GUI-прогон не подтверждён: сначала Mac был заблокирован, затем инструмент возвращал timeout при получении окна Equinox. Разрешения TCC не сбрасывались, реальные пользовательские события не изменялись.
- `./scripts/capture-app-store.sh`: Release-тест генерации прошёл отдельно для ru/RU и en/US, без ошибок и пропусков. Результаты: `build/AppStoreListing/run-NRBCKU/`. Проверены шесть RGB PNG 2880×1800 без alpha; все кадры просмотрены, текст и интерфейс помещаются. Это реальные SwiftUI views с изолированными вымышленными событиями, не подтверждение работы живого EventKit.

## Подготовка карточки App Store — 2026-09-29

- App ID: `6806746414`, название Equinox Calendar, версия магазина 1.0.
- Сохранены категория Utilities, название и подзаголовки на русском и английском.
- Заполнена возрастная анкета: 4+ с региональными эквивалентами. Нет веб-браузера внутри приложения, публичного пользовательского контента, чата, рекламы, азартных игр или возрастного контента.
- App Privacy опубликован: «Сбор данных не ведётся». Политика конфиденциальности задана для русского и английского языков.
- Сохранена бесплатная цена (0 во всех валютах) и доступность в 175 странах/регионах после релиза.
- Уже существующая декларация DSA: разработчик не является продавцом. Она не менялась.
- В форме версии выбрана сборка 1.0.0 (6), заполнены описания, ключевые слова, Support URL, copyright и Notes for Review; требование входа отключено. Автоматический релиз после одобрения оставлен как был.
- Форма версии и обе локализации сохранены. Контакты App Review взяты из карточки Cassini по прямому указанию владельца; телефон и email не записаны в репозиторий. Тексты и статус отправки сохранены в `docs/app-store/metadata-1.0.json`.
- Загружены по три скриншота на русском и английском: календарь, детали события, тёмная тема. Порядок проверен в каждой локализации; личных календарных данных в изображениях нет. Исходные PNG: `docs/app-store/screenshots/`.
- Повторный `./run.sh` прошёл успешно (`build/app-store-gui-recheck.log`). Процесс Release запущен, но Computer Use возвращает timeout при получении окна Equinox; владельцу предложено открыть панель через значок строки меню. Живой прогон не подтверждён.
- Валидация «Добавить для проверки» прошла без обязательных замечаний. Выполнена отдельная команда «Отправить на проверку»; Apple подтвердил отправку одного объекта и статус «Ожидание проверки».
- Submission ID: `f75f9af9-2220-4f32-8868-5f6c73300258`, дата: 2026-09-29 13:38 MSK.
- Подтверждение отправки: `build/TestFlight/2026-09-29-app-store/submitted-for-review.png`; App Privacy: `privacy-published.png` в той же папке.

## Ограничения и оставшиеся проверки

- Обновление 1.0.2 (9) ожидает App Review; версия 1.0.1 (8) уже выпущена.
  Успешная обработка пакета и локальная проверка не означают одобрение Apple.
- Полный ручной UI-чеклист AGENTS.md §6 и живой цикл EventKit fetch/create/delete не подтверждены из-за недоступности окна для Computer Use. Автоматические тесты и рендеры не отмечены как ручные проверки. Реальные события не менялись.

Публикация документов завершена: PRIVACY.md и SUPPORT.md в GitHub `main`, коммит `eb8ebc6`.
Оба URL проверены без авторизации: HTTP 200, содержимое совпадает с локальными файлами.
Отдельный Privacy Report из Organizer не формировался; manifests проверены в distribution-пакете.

## Значения для App Store Connect

- Цена: бесплатно, без IAP/подписок.
- Категория: Utilities (соответствует Info.plist).
- Privacy Policy URL: https://github.com/ksandrpetrov/equinox/blob/main/PRIVACY.md
- Support URL: https://github.com/ksandrpetrov/equinox/blob/main/SUPPORT.md
- App Privacy: по текущим потокам приложения — **Data Not Collected**, tracking отсутствует. Локальная обработка календаря не является сбором разработчиком по определению Apple. Добровольные публичные обращения в GitHub описаны отдельно; при добавлении новых сервисов ответы пересмотреть.
- Export compliance: текущее ITSAppUsesNonExemptEncryption=false; собственная криптография не обнаружена, ссылки открываются внешними приложениями. App Store Connect принял выбранную сборку при валидации и отправке; дополнительных обязательных вопросов о шифровании не было.

### Notes for Review (English, отправлены со сборкой 7)

Build 1.0.0 (7) addresses Guideline 4 by adding a native menu with Quit Equinox directly to the menu bar icon.

Equinox is a free macOS menu bar calendar for Apple Silicon, requiring macOS 26 or later.
After launch, click the Equinox icon in the menu bar to open the calendar panel.
To quit, right-click (or Control-click) the Equinox menu bar icon and choose
"Quit Equinox". The same menu provides Preferences. Alternatively, open the calendar
panel, click its ellipsis (…) menu, and choose "Quit Equinox". Quit does not require
Calendar permission. There is normally no Dock icon. No Equinox account or purchase is required.

Allow Calendar Full Access to display events from calendars configured in macOS.
Without access, month navigation remains available and the app explains how to grant access.
To test creation, use a writable system calendar and the New Event action (Command-N).
Open that event to view details and delete it with confirmation. Existing events cannot be edited;
participation status is read-only. Read-only calendars do not permit deletion.

Meeting links open the installed meeting client where supported, with a web fallback.
The meeting provider may require its own account. Launch at login is optional and enabled
by the user in General settings. Privacy Policy is in Privacy and About; Support and
bundled third-party licenses are in About. Calendar contents and settings are not sent
to a developer-operated service.

## Источники

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [Manifest placement](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

## Попытка загрузки 2026-09-29

По команде пользователя подготовлена distribution-сборка **1.0.0 (6)**.
Номер передан через CURRENT_PROJECT_VERSION=6 при архивировании; исходники подписи
и Local.xcconfig не менялись. Проверены сертификаты приложения, EquinoxKit и
KeyboardShortcuts resource bundle: они совпадают с DeveloperCertificates профиля.
Проверены оба privacy manifests, Sandbox/calendar entitlements и отсутствие get-task-allow.
Готовый пакет: `build/TestFlight/2026-09-29-app-store/VerifiedExport/equinox.pkg`.

Попытка загрузки в 11:48 MSK остановлена до отправки: `exportArchive Failed to Use Accounts`.
Причиной первой попытки была истёкшая авторизация Apple Account для команды H23ADBVT65.
Пользователь восстановил вход в Xcode и App Store Connect.
Архив и пакет сохранены; проверка и журналы — `build/TestFlight/2026-09-29-app-store/`.
После обновления авторизации повторная отправка завершилась **успешно в 12:35:57 MSK**.
App Store Connect подтвердил **«Завершено»** для загрузки и **«Готово к отправке»**
для сборки **1.0.0 (6)**. Ошибок обработки нет.
ID сборки: `a9c3ee3b-c7de-47c9-a0c6-fce5c64f21af`.
Подтверждение: `build/TestFlight/2026-09-29-app-store/build6-processed.png`.
Журнал: `build/TestFlight/2026-09-29-app-store/upload-retry.log`.
Этот distribution-пакет заменяет предыдущий ad-hoc-архив для отправки;
отправка на App Review завершена 29 сентября в 13:38 MSK. Ограничения живого UI-прогона указаны выше.

PRIVACY.md и SUPPORT.md опубликованы 2026-09-29 в GitHub `main` коммитом `eb8ebc6`.
Публичные ссылки из приложения возвращают HTTP 200 без авторизации; опубликованные
файлы побайтово совпадают с подготовленными документами.
