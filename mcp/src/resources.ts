import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

const calendarDocs = `# Equinox Calendar MCP

Локальный MCP-сервер для управления и анализа системных календарей macOS через EventKit.

## Архитектура

- **MCP server** (\`mcp/\`) — TypeScript, stdio transport
- **equinox-bridge** — Swift CLI, JSON-команда в argv, JSON-ответ в stdout, прямой доступ к \`EKEventStore\`

MCP работает без запущенного GUI equinox.

## Доступ и разрешения

- \`equinox-bridge\` — отдельный бинарник (\`com.equinox.equinox-bridge\`)
- macOS запросит доступ к календарю независимо от equinox.app
- Перед чтением/записью вызовите \`get_calendar_access_status\` или \`request_calendar_access\`

## Ограничения

- Только macOS
- Чтение событий ограничено 500 за запрос
- Аналитика считается in-memory в MCP из событий диапазона
- Declined-приглашения скрываются в bridge/MCP; в GUI equinox показываются приглушёнными
- Подписанные read-only календари нельзя изменять

## Сборка

\`\`\`bash
./scripts/build-mcp.sh
\`\`\`

## Инструменты

**Управление:** get_calendar_access_status, request_calendar_access, list_calendars, list_events, get_event, create_event, update_event, delete_event

**Аналитика:** analyze_schedule, find_conflicts, find_free_time
`

const eventSchema = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  title: "EquinoxBridgeEvent",
  type: "object",
  required: [
    "calendarItemIdentifier",
    "title",
    "startDate",
    "endDate",
    "isAllDay",
    "calendarIdentifier",
    "calendarTitle",
    "calendarColorHex",
    "allowsContentModifications",
    "hasAttendees",
  ],
  properties: {
    eventIdentifier: { type: ["string", "null"] },
    calendarItemIdentifier: { type: "string" },
    title: { type: "string" },
    location: { type: ["string", "null"] },
    notes: { type: ["string", "null"] },
    url: { type: ["string", "null"] },
    startDate: { type: "string", description: "ISO-8601 instant" },
    endDate: { type: "string", description: "ISO-8601 instant" },
    isAllDay: { type: "boolean" },
    joinURL: { type: ["string", "null"], description: "Detected meeting URL" },
    calendarIdentifier: { type: "string" },
    calendarTitle: { type: "string" },
    calendarColorHex: { type: "string", pattern: "^#[0-9A-F]{6}$" },
    allowsContentModifications: { type: "boolean" },
    hasAttendees: { type: "boolean" },
  },
  additionalProperties: false,
}

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
          text: JSON.stringify(eventSchema, null, 2),
        },
      ],
    }),
  )
}
