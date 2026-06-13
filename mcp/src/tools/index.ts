import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { registerAnalyticsTools } from "./events.js"
import { registerCalendarTools } from "./calendars.js"
import { registerEventTools } from "./events.js"

export function registerTools(server: McpServer) {
  registerCalendarTools(server)
  registerEventTools(server)
  registerAnalyticsTools(server)
}
