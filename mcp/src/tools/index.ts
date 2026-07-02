import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { registerAnalyticsTools, registerEventTools } from "./events.js"
import { registerCalendarTools } from "./calendars.js"
import { registerPlaudTools } from "./plaud.js"

export function registerTools(server: McpServer) {
  registerCalendarTools(server)
  registerEventTools(server)
  registerAnalyticsTools(server)
  registerPlaudTools(server)
}
