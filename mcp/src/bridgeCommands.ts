import { MCP_TOOL_NAMES } from "./tools/registry.js"

export type BridgeToolCommand = {
  tool: (typeof MCP_TOOL_NAMES)[number]
  command?: string
  requiredPayloadKeys: string[]
  usesBridge: boolean
}

/**
 * Maps MCP tool names to equinox-bridge `command` strings and minimal payload keys.
 * Plaud tools read local cache only and do not invoke the bridge.
 */
export const BRIDGE_TOOL_COMMANDS: BridgeToolCommand[] = [
  { tool: "get_calendar_access_status", command: "access_status", requiredPayloadKeys: ["command"], usesBridge: true },
  { tool: "request_calendar_access", command: "request_access", requiredPayloadKeys: ["command"], usesBridge: true },
  { tool: "list_calendars", command: "list_calendars", requiredPayloadKeys: ["command"], usesBridge: true },
  {
    tool: "list_events",
    command: "list_events",
    requiredPayloadKeys: ["command", "startDate", "endDate"],
    usesBridge: true,
  },
  {
    tool: "get_event",
    command: "get_event",
    requiredPayloadKeys: ["command", "eventIdentifier"],
    usesBridge: true,
  },
  {
    tool: "create_event",
    command: "create_event",
    requiredPayloadKeys: ["command", "title", "startDate", "endDate"],
    usesBridge: true,
  },
  {
    tool: "update_event",
    command: "update_event",
    requiredPayloadKeys: ["command", "eventIdentifier"],
    usesBridge: true,
  },
  {
    tool: "delete_event",
    command: "delete_event",
    requiredPayloadKeys: ["command", "eventIdentifier"],
    usesBridge: true,
  },
  {
    tool: "analyze_schedule",
    command: "list_events",
    requiredPayloadKeys: ["command", "startDate", "endDate"],
    usesBridge: true,
  },
  {
    tool: "find_conflicts",
    command: "list_events",
    requiredPayloadKeys: ["command", "startDate", "endDate"],
    usesBridge: true,
  },
  {
    tool: "find_free_time",
    command: "list_events",
    requiredPayloadKeys: ["command", "startDate", "endDate"],
    usesBridge: true,
  },
  { tool: "get_plaud_status", requiredPayloadKeys: [], usesBridge: false },
  { tool: "list_plaud_recordings", requiredPayloadKeys: [], usesBridge: false },
]
