import { z } from "zod"
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { invokeBridge, requireBridgeData } from "../bridge.js"
import type {
  AccessRequestData,
  AccessStatusData,
  CalendarsData,
} from "../types.js"

function jsonToolResult(value: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: value as Record<string, unknown>,
  }
}

export function registerCalendarTools(server: McpServer) {
  server.registerTool(
    "get_calendar_access_status",
    {
      title: "Статус доступа к календарю",
      description:
        "Проверяет TCC-разрешение EventKit для equinox-bridge. Используйте перед чтением или изменением событий.",
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async () => {
      const response = invokeBridge<AccessStatusData>({ command: "access_status" })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "request_calendar_access",
    {
      title: "Запросить доступ к календарю",
      description:
        "Запрашивает доступ к системным календарям macOS через EventKit. Может показать системный диалог разрешений.",
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async () => {
      const response = invokeBridge<AccessRequestData>({ command: "request_access" })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "list_calendars",
    {
      title: "Список календарей",
      description:
        "Возвращает все доступные календари EventKit с источником, цветом и флагом allowsContentModifications.",
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async () => {
      const response = invokeBridge<CalendarsData>({ command: "list_calendars" })
      return jsonToolResult(requireBridgeData(response))
    },
  )
}
