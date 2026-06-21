import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

import { bridgeEventSchema, mcpEnrichedEventSchema } from "../src/schemas/index.js"

const fixtureDir = join(dirname(fileURLToPath(import.meta.url)), "fixtures")
const bridgeEvents = JSON.parse(
  readFileSync(join(fixtureDir, "bridge-events.json"), "utf8"),
) as Record<string, unknown>[]

/** Golden keys shared with `equinoxTests/BridgeEventFixturesTests.swift`. */
const fullEventKeys = new Set([
  "eventIdentifier",
  "calendarItemIdentifier",
  "title",
  "location",
  "notes",
  "url",
  "startDate",
  "endDate",
  "isAllDay",
  "joinURL",
  "calendarIdentifier",
  "calendarTitle",
  "calendarColorHex",
  "allowsContentModifications",
  "hasAttendees",
  "participationStatus",
])

const minimalEventKeys = new Set([
  "calendarItemIdentifier",
  "title",
  "startDate",
  "endDate",
  "isAllDay",
  "calendarIdentifier",
  "calendarTitle",
  "calendarColorHex",
  "allowsContentModifications",
  "hasAttendees",
])

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
})
