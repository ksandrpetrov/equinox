# Equinox privacy policy / Политика конфиденциальности

Effective date / Дата: 2026-09-29

## English

Equinox is a free calendar app for the macOS menu bar, maintained at
[ksandrpetrov/equinox](https://github.com/ksandrpetrov/equinox).
It has no account system, advertising, analytics SDK, tracking, or developer-operated backend.
The developer does not receive your calendar data or app preferences.

### Calendar access and use

With your permission, Equinox uses macOS EventKit to read calendars and events,
including titles, times, locations, notes, event URLs and your participation status.
It uses this information to display your agenda and detect meeting links. Equinox
also creates and deletes events when you explicitly perform those actions.
Full Calendar Access is needed for these features. Calendar data is processed on
your Mac and cached in memory; Equinox does not maintain its own calendar database.

Events created or deleted through Equinox belong to your system calendars. macOS
and your configured calendar providers (for example iCloud or Exchange) may sync
those changes under their own policies. Removing Equinox does not delete those events.

### Settings, links and third-party software

Preferences, selected calendar identifiers and keyboard shortcuts are stored locally
using macOS preferences. KeyboardShortcuts stores the shortcut you choose; it does
not send it to the developer. The app uses a local monotonic timer to control its
loading indicator, not to identify or track you.

Opening a meeting, event link, support page or this policy sends the selected URL
to your browser or another installed app. Meeting URLs may contain meeting IDs and
access tokens. The destination service handles that visit under its own privacy
policy. Equinox does not automatically join meetings or upload your calendar to it.

### Retention and control

You can revoke Calendar Full Access in System Settings → Privacy & Security →
Calendars. Equinox clears its event cache when it observes loss of access; closing
the app releases its in-memory cache. Local preferences persist between launches.
Settings → General → Reset All Settings to Defaults resets app preferences, calendar
selection and the app shortcut, and attempts to disable launch at login; any failure
is shown. This does not delete calendar events or revoke the macOS permission.
Manage or delete events in your calendar, and manage synchronized copies through
your calendar provider. There is no developer-held calendar database to erase.

### Support and changes

Contact the maintainer through [GitHub Issues](https://github.com/ksandrpetrov/equinox/issues).
Issues are public: do not include personal calendar contents, meeting credentials,
or other sensitive information. Information you voluntarily post is hosted by GitHub
under its policies, and is used by the maintainer to answer the request.
This policy will be updated when the app's data practices change.

## Русский

Equinox — бесплатный календарь для строки меню macOS. Проект поддерживается в
[ksandrpetrov/equinox](https://github.com/ksandrpetrov/equinox).
В приложении нет аккаунтов, рекламы, аналитики, отслеживания или сервера разработчика.
Разработчик не получает ваши события и настройки приложения.

### Доступ к календарям

С вашего разрешения Equinox читает через macOS EventKit календари и события:
названия, время, места, заметки, ссылки и ваш статус участия. Эти данные нужны для
показа расписания и поиска ссылок на встречи. Приложение также создаёт и удаляет
события по вашему явному действию. Для этих функций нужен полный доступ к календарям.
Данные обрабатываются на Mac и временно хранятся в памяти; собственной базы событий
у Equinox нет.

Созданные и удалённые события относятся к системным календарям. macOS и настроенные
провайдеры, например iCloud или Exchange, могут синхронизировать изменения по своим
правилам. Удаление Equinox не удаляет события из календарей.

### Настройки, ссылки и сторонний код

Настройки, идентификаторы выбранных календарей и сочетания клавиш сохраняются
локально в настройках macOS. Библиотека KeyboardShortcuts сохраняет выбранную
горячую клавишу и не отправляет её разработчику. Локальный монотонный таймер служит
для отображения индикатора загрузки, а не для идентификации пользователя.

При открытии встречи, ссылки события, поддержки или этой политики выбранный URL
передаётся браузеру либо установленному приложению. Ссылки встреч могут содержать
идентификаторы и коды доступа. Дальнейшая обработка регулируется политикой сервиса.
Equinox не подключается к встречам автоматически и не загружает туда ваш календарь.

### Хранение и управление

Отозвать полный доступ можно в «Системные настройки → Конфиденциальность и
безопасность → Календари». При обнаружении отзыва доступа Equinox очищает кэш
событий; завершение приложения освобождает кэш в памяти. Настройки сохраняются между
запусками. Сброс в разделе «Основные» возвращает настройки к значениям по умолчанию,
сбрасывает выбор календарей и горячую клавишу, а также пытается выключить автозапуск;
ошибка отображается пользователю. Сброс не удаляет события и не отзывает разрешение macOS.
Удаляйте события через календарь, а синхронизированные копии — через его провайдера.
У разработчика нет базы ваших календарей, которую требовалось бы удалять.

### Поддержка и изменения

Связаться с автором можно через [GitHub Issues](https://github.com/ksandrpetrov/equinox/issues).
Обращения публичны: не добавляйте личные события, коды встреч и другие чувствительные
данные. Добровольно опубликованные сведения хранятся в GitHub по его правилам и
используются автором для ответа на обращение. При изменении обработки данных эта
политика будет обновлена.
