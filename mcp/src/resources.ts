import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { eventResourceSchema } from "./schemas/resourceSchemas.js"

const calendarDocs = `# Equinox Calendar MCP

Локальный MCP-сервер для управления и анализа системных календарей macOS через EventKit. Он умеет читать календари и события, создавать/обновлять/удалять события по явной просьбе пользователя, считать загрузку, искать конфликты и свободное время, а также читать локальный кэш Plaud-записей Equinox.

## Архитектура

- **MCP server** (\`mcp/\`) — TypeScript, stdio transport
- **Equinox app bridge** — локальный loopback proxy внутри запущенного equinox.app
- **equinox-bridge** — Swift CLI, JSON-команда в argv, JSON-ответ в stdout, доступ к \`EKEventStore\`

MCP сначала использует запущенное приложение Equinox, чтобы macOS применяла Calendar permission Equinox. Если приложение не запущено, MCP пробует прямой fallback на \`equinox-bridge\`.

## Доступ и разрешения

- Основной путь: equinox.app запускает \`equinox-bridge\` от своего имени через локальный proxy
- Прямой fallback на \`equinox-bridge\` может быть заблокирован TCC, если AI-клиент не имеет Calendar entitlement
- Перед чтением/записью вызовите \`get_calendar_access_status\` или \`request_calendar_access\`

## Ограничения

- Только macOS
- Чтение событий ограничено 500 за запрос
- Аналитика считается in-memory в MCP из событий диапазона (максимум 366 дней)
- Даты YYYY-MM-DD — локальная таймзона машины; endDate включительно
- Мутирующие MCP-команды не повторяются через CLI после таймаута app bridge
- Bridge работает только с EventKit; Plaud, prompts и analytics находятся на уровне MCP
- Plaud-инструменты читают только локальный кэш Equinox и не обновляют каталог через Plaud API
- list_events/get_event автоматически добавляют hasPlaudRecording и plaudRecording из локального Plaud-кэша, если есть привязка
- Declined-приглашения скрываются в bridge/MCP; в GUI equinox показываются приглушёнными
- Подписанные read-only календари нельзя изменять

## Сборка

\`\`\`bash
./scripts/build-mcp.sh
\`\`\`

## Инструменты

**Управление:** get_calendar_access_status, request_calendar_access, list_calendars, list_events, get_event, create_event, update_event, delete_event

**Аналитика:** analyze_schedule, find_conflicts, find_free_time

**Plaud:** get_plaud_status, list_plaud_recordings

## Prompts

daily_agenda, weekly_calendar_review

## Resources

equinox://docs/calendar, equinox://schema/event
`

export function registerResources(server: McpServer) {
  server.registerResource(
    "equinox_docs_calendar",
    "equinox://docs/calendar",
    {
      title: "Документация Equinox Calendar MCP",
      description: "Как работает доступ EventKit, ограничения и инструменты MCP.",
      mimeType: "text/markdown",
    },
    async (uri) => ({
      contents: [
        {
          uri: uri.href,
          mimeType: "text/markdown",
          text: calendarDocs,
        },
      ],
    }),
  )

  server.registerResource(
    "equinox_schema_event",
    "equinox://schema/event",
    {
      title: "JSON Schema события equinox-bridge",
      description: "Поля события, возвращаемые equinox-bridge и MCP tools.",
      mimeType: "application/json",
    },
    async (uri) => ({
      contents: [
        {
          uri: uri.href,
          mimeType: "application/json",
          text: JSON.stringify(eventResourceSchema, null, 2),
        },
      ],
    }),
  )
}
