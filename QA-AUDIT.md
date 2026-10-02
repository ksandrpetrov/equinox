# Аудит equinox — 2 октября 2026

## Что изменено

Исходная ревизия: `7690c86` (`main`), рабочее дерево перед аудитом чистое.
Среда: Apple Silicon, macOS 27.0.1 (26A434), Xcode 27.0 (27A266a).

Исправлен один подтверждённый дефект обработки внешних ссылок. Добавлены пять
тестов в существующие XCTest-наборы. Итоговая матрица Debug/Release проходит;
живой цикл EventKit и полный UI smoke не завершены из-за блокировки Mac.
Готовность к выпуску этим проходом **не подтверждена**.

### QA-01: локальные ресурсы из календаря передавались в Launch Services

- Приоритет: P2, требует нажатия пользователем на ссылку события.
- Путь: URL приглашения/подписного события → EventDetailView → URLOpener →
  NSWorkspace. До исправления отсутствовала проверка типа ресурса как для
  основной ссылки, так и для fallback.
- Воспроизведение: передать `file:///Applications/Calculator.app`,
  `FILE:///tmp/invitation.command`, `javascript:alert(1)`, `data:text/html,hello`
  или относительный путь в URLOpener с регистрирующим подставным opener.
  Исходный код передавал их opener; после исправления они туда не попадают.
- Опасность: открытие файла через NSWorkspace может запускать обработчик файла
  или приложение. Это проверка достижения системного вызова, **не** доказательство
  эксплуатации или автоматического исполнения без клика. При тестировании
  реальные приложения, команды и внешние ссылки не запускались.
- Исправление: проверять абсолютность/корректность URL и запрещать схемы `file`,
  `javascript`, `data` без учёта регистра. Независимо проверять fallback;
  безопасный fallback после отвергнутой основной ссылки остаётся доступен.
- Сохранены web, native meeting URLs, tel, mailto, equinox и остальные custom
  schemes. Это узкое ограничение локальных ресурсов, а не полная песочница для
  всех внешних обработчиков URL. Уже сохранённые события не переписываются;
  при запрещённой ссылке используется существующая ошибка открытия.
- Доказательство до исправления: 3 новых теста упали, 2 существовавших прошли,
  [xcresult](build/Tests/results/run-vL8wNo/equinoxTests-Debug.xcresult),
  [журнал](build/QA/url-before.log).
- После исправления все 5 тестов URLOpener проходят в обычной матрице и с
  санитайзерами. Изменение: [URLOpener.swift](equinox/Services/Platform/URLOpener.swift),
  проверки: [URLOpenerTests.swift](equinoxTests/URLOpenerTests.swift).

Семантика системного открытия ресурсов сверена с
[документацией Apple NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace).

### Расширение проверок

- [CalendarDateTests](equinoxTests/CalendarDateTests.swift): первые и последние
  дни каждого месяца 1583–3333 сопоставляются с Foundation, включая ISO week
  numbers и преобразование Date ↔ CalendarDate. Это 42 024 граничные даты.
  Существующий исчерпывающий тест 639 540 гражданских дат также прошёл.
- [AgendaSectionsTests](equinoxTests/AgendaSectionsTests.swift): синтетические
  наборы 100 / 1 000 / 10 000 событий, уникальность экземпляров, отсутствие потерь,
  порядок по времени, один вызов resolver для общего meeting URL, фильтрация и
  освобождение словарей старых дней при смене диапазона. Время сохраняется в
  XCTAttachment; произвольного порога производительности в тесте нет.

## Почему так

Изучены AGENTS.md, ARCHITECTURE.md, BUILD.md, предыдущие отчёты и реализация
критичных потоков: AppState/координаторы, CalendarStore/кэш/выбор календарей,
маппинг и мутации EventKit, даты/черновики/повторения, meeting URLs, настройки,
жизненный цикл панели и основные views.

Большая часть предложенных регрессий уже существовала: устаревшие снимки после
отзыва доступа или смены календаря, повторное удаление во время reload, ошибки
после успешной записи, DST, границы диапазонов и сохранение заметок. Эти проверки
были исполнены, а не продублированы ради количества тестов.

Production diff ограничен существующим сервисом открытия URL. Новые targets,
зависимости, UserDefaults-ключи и механизмы доступа к EventKit не добавлялись.
Публичные сигнатуры, deep links, signing в project.pbxproj и локализация не
изменены. Проверки добавлены в уже подключённые исходники XCTest.

## Проверки

### Исполненные прогоны

| Проверка | Результат | Артефакт |
|---|---|---|
| Исходный `./scripts/test.sh` | В каждой конфигурации 386 unit + 20 graphics; 0 failed/skipped | [run-kAXuhX](build/Tests/results/run-kAXuhX) |
| Регрессии URL до исправления | 2 passed, 3 failed; ожидаемое воспроизведение | [url-before.log](build/QA/url-before.log) |
| Первый полный unit после исправления | Debug: 390 passed; нагрузочный тест добавлен следующим шагом | [run-9mASn7](build/Tests/results/run-9mASn7) |
| Итоговый `./scripts/test.sh` | Debug: 391 unit + 20 graphics; Release: 391 unit + 20 graphics; всего 822 исполнения, 0 failed/skipped/runtime warnings | [run-TIwH2G](build/Tests/results/run-TIwH2G) |
| Thread Sanitizer, Debug unit | 391 passed, 0 failed/skipped/runtime warnings; сообщений TSan нет | [журнал](build/QA/thread-sanitizer.log), [сводка](build/QA/thread-sanitizer-summary.json) |
| Address Sanitizer, Debug unit | 391 passed, 0 failed/skipped/runtime warnings; сообщений ASan нет | [журнал](build/QA/address-sanitizer.log), [сводка](build/QA/address-sanitizer-summary.json) |
| Русский язык, RU, unit до изменений | 386 passed, 0 failed/skipped | [сводка](build/QA/unit-ru-before-summary.json) |
| Русский язык, RU, Release graphics | 20 passed, 0 failed/skipped/runtime warnings | [журнал](build/QA/graphics-ru.log), [изображения](build/QA/graphics-ru-attachments) |
| Английский язык, US, Release graphics | 20 passed, 0 failed/skipped/runtime warnings | [журнал](build/QA/graphics-en.log), [изображения](build/QA/graphics-en-attachments) |
| Xcode analyze, Release, до/после | ANALYZE SUCCEEDED; собственных диагностик приложения не найдено | [итоговый журнал](build/QA/analyze-after.log) |
| `./run.sh` | BUILD SUCCEEDED; Release-процесс запущен и оставался жив при последующих проверках | [журнал](build/QA/release-launch.log) |
| Подпись | `codesign --verify --deep --strict` успешен; Sandbox и calendars entitlement присутствуют | Локальная development-подпись; не distribution-проверка |
| Diff | `git diff --check` прошёл; project.pbxproj и Package.resolved не изменены | Рабочее дерево |

Для санитайзеров использованы существующая схема equinoxTests и отдельные
DerivedData в `build/QA/{ThreadSanitizer,AddressSanitizer}`; параметры
`-enableThreadSanitizer YES` / `-enableAddressSanitizer YES`,
`CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES`. Для локализаций — штатная
схема equinoxGraphicsTests с `-testLanguage ru -testRegion RU` либо
`-testLanguage en -testRegion US`. Полные вызовы xcodebuild находятся в начале
соответствующих журналов. Закреплённые пакеты использованы без обновления.

Xcode analyze и санитайзеры не доказывают отсутствие ошибок в неисполненных
ветках. CalendarStore имеет 0 исполненных строк в изолированных наборах по
устройству тестового контура: graphics host не обращается к пользовательскому
EventKit. Проценты unit и graphics coverage не суммируются.

### Матрица сценариев

| Область | Что проверено | Практический предел |
|---|---|---|
| Даты и сетка | Весь поддерживаемый диапазон, все варианты week start/rows из существующей матрицы, leap years, ISO weeks, границы месяцев/лет | Реальная смена системного календаря/часового пояса не выполнялась |
| DST и all-day | Пропущенный день Apia, повторяющийся час, переходы Los Angeles/Lord Howe, длительности и исключительный конец | Системный EventKit не записывался |
| Fetch и кэш | Очередь, coalescing, запоздавшие ответы, ревизии, фильтрация, eviction, chunks и ошибки | Настоящие запросы CalendarStore не подтверждены наблюдением UI |
| Создание/удаление | Валидация, несохранённые EKEvent, recurrence/alarm mapping, отказ записи, двойное удаление, reload после записи | Нет живой проверки удаления отдельного/последнего повторения |
| Доступ | Mapping full/write-only/denied/restricted, отзыв доступа и очистка UI через stub | TCC не сбрасывался; реальное изменение доступа не проверено |
| Agenda | Фокус Today, прокрутка, расширение диапазона, дальняя дата, быстрая навигация | Жесты живого пользователя не выполнены |
| Meeting URLs | Реестр, обманные домены, native fallback, параметры встреч, заметки, новое ограничение локальных ресурсов | Внешние meeting clients не запускались |
| Настройки | Persistence/reset/нормализация, уведомления, смена writable calendar, ошибки launch at login | Настоящий системный автозапуск не переключался |
| Панель и shortcut | Pin/modal/cancel state, hit area, capture lifecycle, таймеры, time/locale notifications | Реальные глобальные клавиши, Spaces и смена монитора не проверены |
| UI | S/M/L, glass/solid, light/dark, состояния доступа/loading/empty/error, длинные строки, шесть вкладок, RU/EN | Рендеры не заменяют живое окно; ограничение sidebar описано ниже |
| Архитектура | DesignSystemComplianceTests, границы слоёв/ресурсов, тестовая сборка Debug/Release | Статический анализ Swift не является полноценным security proof |

### Производительность и память

Из итогового Release XCTest, один замер на набор, без санитайзера:

| Событий | Построение и сортировка DayEvent |
|---:|---:|
| 100 | 4,41 мс |
| 1 000 | 24,90 мс |
| 10 000 | 155,99 мс |

Доказательства: [unit-release-attachments](build/QA/unit-release-attachments).
Измеряется обработка синтетических данных, без EventKit I/O и времени рендера.
Набор содержит один повторяющийся meeting URL; это не оценка загрузки 10 000
уникальных ссылок или аккаунтов.

Существующий graphics-сценарий с 4 155 событиями и 24 переходами по месяцам:
сумма синхронных layout/display-участков 420,40 мс, худший 52,12 мс.
Проверка ограничения количества fetch прошла. Это не измерение полного FPS;
задержки между командами и асинхронная работа в сумму не включены.

Живой Release-процесс: footprint 19,0 МБ, peak 71,0 МБ на момент измерения.
`leaks` дважды сообщил 415 allocations / 19 888 bytes в трёх циклах
NSXPCConnection; между снимками объём не изменился. Те же три дерева, с теми же
размерами, найдены в graphics host без CalendarStore. Это указывает на общую
framework/runtime-причину, но без allocation stacks её точное происхождение
не доказано. Никакие suppressions не добавлены.

В graphics host во время тестов leaks дополнительно отметил SwiftUI dictionary
cycle и NSDisplayLink, всего 576 allocations / 39 568 bytes; это не объявляется
утечкой production AppState и не считается чистым leak-прогоном.
Артефакты: [Release](build/QA/release-leaks.log),
[повторный снимок](build/QA/release-leaks-followup.log),
[graphics host](build/QA/graphics-host-leaks.log).
После наблюдения памяти сравнительный Release graphics-прогон завершился
20 passed: [журнал](build/QA/graphics-leak-comparison.log).

## Риски

1. **Живой EventKit и интерактивный UI остаются открытыми.** Computer Use дважды
   сообщил заблокированный Mac и приостановленную автоматическую разблокировку.
   Пользователю отправлен запрос ручной разблокировки. Обход блокировки не
   предпринимался. Запуск процесса не засчитан как полный smoke test.
2. **Selected sidebar row в bitmap-рендерах.** В settings-снимках выбранная
   строка бывает сплошной чёрной, без текста. Эксперимент с показом окна перед
   захватом дал чёрный bitmap; экспериментальное изменение test helper отменено.
   На заблокированном Mac нельзя уверенно отличить дефект UI от ограничения
   AppKit/compositor capture. Проверить живое окно после разблокировки.
   [Снимок](build/QA/graphics-ru-attachments/E1AF4ECA-43F6-4E5D-926B-B9B48DEFE6C3.png).
3. **Диагностики памяти не закрыты.** Небольшие NSXPC cycles воспроизводятся
   независимо от CalendarStore. Нет длительного профилирования реальной
   навигации/открытия панели и allocation stacks для строгой атрибуции.
4. В журналах присутствуют ошибки подключения к системному
   `com.apple.linkd.autoShortcut`; они есть и в изолированных тестах.
   Отдельных сообщений TSan/ASan или SwiftUI state/layout warnings нет.
   Установить связь этих системных сообщений с NSXPC cycles пока нельзя.
5. Локальная Release-сборка имеет development entitlement `get-task-allow=true`.
   Она подходит для локальной диагностики; этот результат не подтверждает
   корректность distribution-архива. Настройки подписи не менялись.
6. macOS 26, реальные calendar providers, несколько дисплеев, VoiceOver и
   длительный sleep/wake цикл не проверены в этой среде.

Визуально просмотрены RU event details, error state S, Privacy settings,
EN dark calendar и writable new-event form S. Их тексты и основные формы
помещаются; остальные изображения проверены автоматической геометрией и
детектором непустого рендера, не объявлены вручную просмотренными.

## Что не сделано

- Отдельный календарь `Equinox QA <идентификатор запуска>` не создан: живой UI
  недоступен. Существующие события не создавались, не редактировались и не
  удалялись. Системные разрешения и автозапуск не менялись.
- Не выполнены настоящие fetch/create/delete/relaunch, включая DST/all-day и
  повторяющиеся события. После разблокировки выполнять их только в отдельном
  тестовом календаре, без участников и alerts; удалять только данные данного
  запуска и восстановить изменённые для проверки настройки.
- Не выполнены публикация приложения, notarization, App Store upload и
  обновление пакетов.
- Не заявляется отсутствие всех дефектов. Подтверждённый QA-01 исправлен;
  наблюдения по sidebar и памяти требуют указанной дополнительной проверки.

Артефакты под `build/` локальные и gitignored. Отчёт и регрессионные тесты
остаются в репозитории; при переносе результатов нужно отдельно сохранить
нужные xcresult, журналы и изображения.
