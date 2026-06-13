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
        "Локальный MCP для управления и анализа системных календарей macOS через EventKit (equinox-bridge). Используйте инструменты для CRUD событий и on-demand аналитики расписания. Перед работой проверьте доступ к календарю. Сервер работает только на macOS и требует собранный equinox-bridge.",
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
