import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

import { BRIDGE_TOOL_COMMANDS } from "../src/bridgeCommands.js"
import { bridgeEventSchema, mcpEnrichedEventSchema } from "../src/schemas/index.js"
import {
  bridgeEventAllKeys,
  bridgeEventOptionalKeys,
  bridgeEventRequiredKeys,
  bridgeUpdateMutableFields,
} from "../src/schemas/generated/bridgeEventKeys.js"
import { createEventInputSchema } from "../src/schemas/toolInputs.js"

const fixtureDir = join(dirname(fileURLToPath(import.meta.url)), "fixtures")
const bridgeEvents = JSON.parse(
  readFileSync(join(fixtureDir, "bridge-events.json"), "utf8"),
) as Record<string, unknown>[]

const fullEventKeys = new Set(bridgeEventAllKeys)
const minimalEventKeys = new Set(bridgeEventRequiredKeys)

describe("bridge schemas", () => {
  it("accepts golden bridge event fixtures", () => {
    for (const event of bridgeEvents) {
      expect(() => bridgeEventSchema.parse(event)).not.toThrow()
    }
  })

  it("accepts MCP enrichment fields on bridge events", () => {
    const parsed = mcpEnrichedEventSchema.parse({
      ...bridgeEvents[0],
      hasPlaudRecording: true,
      plaudRecording: {
        fileID: "rec-1",
        webURL: "https://plaud.ai/r/1",
        source: "manual",
      },
    })
    expect(parsed.hasPlaudRecording).toBe(true)
  })

  it("parses Swift-style ISO instants with fractional seconds", () => {
    const parsed = bridgeEventSchema.parse(bridgeEvents[0])
    const start = new Date(parsed.startDate)
    expect(Number.isNaN(start.getTime())).toBe(false)
    expect(parsed.startDate).toMatch(/\.000Z$/)
  })

  it("keeps golden fixture key sets in sync with Swift contract tests", () => {
    expect(new Set(Object.keys(bridgeEvents[0]))).toEqual(fullEventKeys)
    expect(new Set(Object.keys(bridgeEvents[1]))).toEqual(minimalEventKeys)
    expect(bridgeEvents[2].participationStatus).toBe("declined")
  })

  it("rejects bridge events missing required fields", () => {
    const { calendarItemIdentifier: _id, ...incomplete } = bridgeEvents[0]
    expect(() => bridgeEventSchema.parse(incomplete)).toThrow()
  })

  it("accepts null optional joinURL and participationStatus", () => {
    const parsed = bridgeEventSchema.parse({
      ...bridgeEvents[1],
      joinURL: null,
      participationStatus: null,
    })
    expect(parsed.joinURL).toBeNull()
    expect(parsed.participationStatus).toBeNull()
  })

  it("accepts all bridge participation status strings from Swift mapping", () => {
    for (const status of ["unknown", "pending", "accepted", "declined", "tentative"]) {
      const parsed = bridgeEventSchema.parse({
        ...bridgeEvents[0],
        participationStatus: status,
      })
      expect(parsed.participationStatus).toBe(status)
    }
  })

  it("keeps declined fixture free of optional join fields", () => {
    const declined = bridgeEvents[2] as Record<string, unknown>
    expect(declined.participationStatus).toBe("declined")
    expect(declined.joinURL).toBeUndefined()
    expect(declined.location).toBeUndefined()
    expect(declined.notes).toBeUndefined()
  })

  it("parses full fixture joinURL as a valid URL", () => {
    const full = bridgeEventSchema.parse(bridgeEvents[0])
    expect(() => new URL(full.joinURL!)).not.toThrow()
    expect(full.joinURL).toContain("zoom.us")
  })

  it("keeps generated updateMutableFields in sync with schema JSON", () => {
    const schemaPath = join(dirname(fileURLToPath(import.meta.url)), "../../bridge/schema/bridge-protocol.schema.json")
    const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as { updateMutableFields: string[] }
    expect([...bridgeUpdateMutableFields]).toEqual(schema.updateMutableFields)
  })

  it("keeps generated optional event keys in sync with schema JSON", () => {
    const schemaPath = join(dirname(fileURLToPath(import.meta.url)), "../../bridge/schema/bridge-protocol.schema.json")
    const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as { bridgeEvent: { optional: string[] } }
    expect([...bridgeEventOptionalKeys]).toEqual(schema.bridgeEvent.optional)
  })

  it("keeps bridge tool commands within schema command list", () => {
    const schemaPath = join(dirname(fileURLToPath(import.meta.url)), "../../bridge/schema/bridge-protocol.schema.json")
    const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as { commands: string[] }
    const schemaCommands = new Set(schema.commands)
    for (const entry of BRIDGE_TOOL_COMMANDS) {
      if (!entry.command) continue
      expect(schemaCommands.has(entry.command)).toBe(true)
    }
  })

  it("rejects create_event with same-day YYYY-MM-DD pair", () => {
    const result = createEventInputSchema.safeParse({
      title: "All-day",
      startDate: "2026-06-14",
      endDate: "2026-06-14",
    })
    expect(result.success).toBe(false)
  })

  it("accepts create_event when endDate is the next calendar day for date-only inputs", () => {
    const result = createEventInputSchema.safeParse({
      title: "All-day",
      startDate: "2026-06-14",
      endDate: "2026-06-15",
    })
    expect(result.success).toBe(true)
  })
})
