import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { getPlaudStatus, listPlaudRecordings } from "../plaud.js"
import { listPlaudRecordingsInputSchema } from "../schemas/toolInputs.js"
import { jsonToolResult } from "../toolResponse.js"

export function registerPlaudTools(server: McpServer) {
  server.registerTool(
    "get_plaud_status",
    {
      title: "Статус Plaud",
      description:
        "Проверяет локальный кэш Plaud в Equinox: есть ли каталог записей, когда он обновлялся и есть ли кэш привязок к событиям.",
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async () => jsonToolResult(await getPlaudStatus()),
  )

  server.registerTool(
    "list_plaud_recordings",
    {
      title: "Список записей Plaud",
      description:
        "Возвращает записи Plaud из локального кэша Equinox за один день (`date`) или диапазон (`startDate` включительно, `endDate` исключительно). Также показывает кэшированные привязки к календарным событиям.",
      inputSchema: listPlaudRecordingsInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => jsonToolResult(await listPlaudRecordings(input)),
  )
}
