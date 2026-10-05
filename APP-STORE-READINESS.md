# Mac App Store readiness — 2026-10-04

## Итог

Исправлены найденные пробелы в privacy-декларациях, описании доступа и лицензиях.
Сборка 1.0.0 (7) подписана для App Store, загружена и успешно обработана Apple.
Политика конфиденциальности, поддержка и App Privacy опубликованы.
Версия магазина 1.0 со сборкой 1.0.0 (7) повторно отправлена на App Review
**4 октября 2026 в 08:05 MSK**. Текущий статус: **Waiting for Review**.
Предыдущая сборка (6) отклонена 3 октября по Guideline 4: ревьюер не нашёл пункт
Quit. Проверка проходила на MacBook Air (15-inch, M3, 2024); исправление описано ниже.
Включён автоматический выпуск после одобрения.
[Подтверждение в App Store Connect](https://appstoreconnect.apple.com/apps/6806746414/distribution/reviewsubmissions/details/f75f9af9-2220-4f32-8868-5f6c73300258).
Проверка App Store Connect и решение App Review не заменяются локальными тестами.

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

- Сборка (7) ожидает повторного App Review после отказа сборки (6) по Guideline 4.
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
