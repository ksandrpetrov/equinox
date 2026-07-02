import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { invokeBridge, requireBridgeData } from "../bridge.js"
import {
  accessRequestOutputSchema,
  accessStatusOutputSchema,
  calendarsDataSchema,
} from "../schemas/outputs.js"
import { jsonToolResult } from "../toolResponse.js"
import { runToolSafely } from "../toolErrors.js"

export function registerCalendarTools(server: McpServer) {
  server.registerTool(
    "get_calendar_access_status",
    {
      title: "Статус доступа к календарю",
      description:
        "Проверяет TCC-разрешение EventKit. Сначала использует equinox.app bridge; при его отсутствии — прямой equinox-bridge CLI. Вызовите перед чтением или изменением событий.",
      outputSchema: accessStatusOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async () => runToolSafely(async () => {
      const response = await invokeBridge({ command: "access_status" })
      return jsonToolResult(requireBridgeData(response, accessStatusOutputSchema))
    }),
  )

  server.registerTool(
    "request_calendar_access",
    {
      title: "Запросить доступ к календарю",
      description:
        "Запрашивает доступ к системным календарям macOS через EventKit. Может показать системный диалог разрешений и ждать ответа пользователя без таймаута.",
      outputSchema: accessRequestOutputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async () => runToolSafely(async () => {
      const response = await invokeBridge({ command: "request_access" })
      return jsonToolResult(requireBridgeData(response, accessRequestOutputSchema))
    }),
  )

  server.registerTool(
    "list_calendars",
    {
      title: "Список календарей",
      description:
        "Возвращает все доступные календари EventKit с источником, цветом и флагом allowsContentModifications.",
      outputSchema: calendarsDataSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async () => runToolSafely(async () => {
      const response = await invokeBridge({ command: "list_calendars" })
      return jsonToolResult(requireBridgeData(response, calendarsDataSchema))
    }),
  )
}
