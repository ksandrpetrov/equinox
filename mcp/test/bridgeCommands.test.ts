import { describe, expect, it } from "vitest"

import { BRIDGE_TOOL_COMMANDS, bridgeCommandForTool } from "../src/bridgeCommands.js"
import { bridgeEventsDataSchema } from "../src/schemas/events.js"
import { MCP_TOOL_NAMES } from "../src/tools/registry.js"

describe("bridge tool command mapping", () => {
  it("covers every registered MCP tool", () => {
    const mappedTools = BRIDGE_TOOL_COMMANDS.map((entry) => entry.tool)
    expect(mappedTools).toEqual([...MCP_TOOL_NAMES])
  })

  it("assigns bridge commands only to bridge-backed tools", () => {
    for (const entry of BRIDGE_TOOL_COMMANDS) {
      if (entry.usesBridge) {
        expect(entry.command, entry.tool).toBeTruthy()
        expect(bridgeCommandForTool(entry.tool)).toBe(entry.command)
      } else {
        expect(entry.command, entry.tool).toBeUndefined()
      }
    }
  })

  it("requires command key in every bridge payload contract", () => {
    for (const entry of BRIDGE_TOOL_COMMANDS.filter((item) => item.usesBridge)) {
      expect(entry.requiredPayloadKeys).toContain("command")
    }
  })
})

describe("bridgeEventsDataSchema", () => {
  it("rejects Plaud enrichment fields from bridge responses", () => {
    expect(() => bridgeEventsDataSchema.parse({
      events: [{
        eventIdentifier: "abc",
        calendarItemIdentifier: "item",
        title: "Meet",
        startDate: "2026-06-13T10:00:00.000Z",
        endDate: "2026-06-13T11:00:00.000Z",
        isAllDay: false,
        calendarIdentifier: "cal-1",
        calendarTitle: "Work",
        calendarColorHex: "#FF0000",
        allowsContentModifications: true,
        hasAttendees: false,
        hasPlaudRecording: true,
      }],
      truncated: false,
    })).toThrow()
  })

  it("accepts pure bridge event payloads", () => {
    expect(() => bridgeEventsDataSchema.parse({
      events: [{
        eventIdentifier: "abc",
        calendarItemIdentifier: "item",
        title: "Meet",
        startDate: "2026-06-13T10:00:00.000Z",
        endDate: "2026-06-13T11:00:00.000Z",
        isAllDay: false,
        calendarIdentifier: "cal-1",
        calendarTitle: "Work",
        calendarColorHex: "#FF0000",
        allowsContentModifications: true,
        hasAttendees: false,
      }],
      truncated: false,
    })).not.toThrow()
  })
})
