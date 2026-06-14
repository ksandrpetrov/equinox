#!/usr/bin/env node
import { pathToFileURL } from "node:url"

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"

import { registerPrompts } from "./prompts.js"
import { registerResources } from "./resources.js"
import { registerTools } from "./tools/index.js"

export function createEquinoxMcpServer(): McpServer {
  const server = new McpServer(
    {
      name: "equinox-calendar-mcp",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
        resources: {},
        prompts: {},
      },
      instructions:
        "Локальный MCP для управления и анализа системных календарей macOS через EventKit. Основной путь использует запущенный equinox.app как локальный proxy к equinox-bridge; без приложения доступ может быть заблокирован TCC клиента. Используйте инструменты для CRUD событий, on-demand аналитики расписания и read-only Plaud-кэша. Перед работой проверьте доступ к календарю; для обзоров доступны prompts daily_agenda и weekly_calendar_review.",
    },
  )

  registerTools(server)
  registerResources(server)
  registerPrompts(server)

  return server
}

export async function runStdioServer() {
  const server = createEquinoxMcpServer()
  const transport = new StdioServerTransport()

  const close = async () => {
    await server.close()
  }
  process.once("SIGINT", () => {
    close().finally(() => process.exit(0))
  })
  process.once("SIGTERM", () => {
    close().finally(() => process.exit(0))
  })

  await server.connect(transport)
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  runStdioServer().catch((error) => {
    console.error(error)
    process.exit(1)
  })
}
