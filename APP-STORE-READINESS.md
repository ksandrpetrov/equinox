# Mac App Store readiness — 2026-09-29

## Итог

Исправлены найденные пробелы в privacy-декларациях, описании доступа и лицензиях.
Сборка 1.0.0 (6) подписана для App Store, загружена и успешно обработана Apple.
Политика конфиденциальности, поддержка и App Privacy опубликованы.
Версия магазина 1.0 со сборкой 1.0.0 (6) отправлена на App Review 29 сентября 2026 в 13:38 MSK.
Статус Apple: **Ожидание проверки**. Включён автоматический выпуск после одобрения.
[Подтверждение в App Store Connect](https://appstoreconnect.apple.com/apps/6806746414/distribution/reviewsubmissions/details/f75f9af9-2220-4f32-8868-5f6c73300258).
Проверка App Store Connect и решение App Review не заменяются локальными тестами.

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

- Окончательное решение App Review ожидается; успешная валидация карточки не гарантирует одобрение.
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

### Notes for Review (English)

Equinox is a free macOS menu bar calendar for Apple Silicon, requiring macOS 26 or later.
After launch, click the Equinox icon in the menu bar. There is normally no Dock icon;
Settings and Quit are available from the panel menu. No Equinox account or purchase is required.

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
