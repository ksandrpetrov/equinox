import { describe, expect, it } from "vitest"

import {
  assertEndAfterStart,
  assertUpdateHasMutableField,
} from "../src/bridgeCommandValidation.js"
import { eventResourceSchema } from "../src/schemas/resourceSchemas.js"
import { mcpEnrichedEventSchema } from "../src/schemas/events.js"

describe("eventResourceSchema", () => {
  it("is generated from mcpEnrichedEventSchema", () => {
    expect(eventResourceSchema.title).toBe("EquinoxBridgeEvent")
    expect(eventResourceSchema.properties?.hasPlaudRecording).toBeDefined()
    expect(eventResourceSchema.properties?.plaudRecording).toBeDefined()
  })

  it("accepts enriched event fixtures through the source Zod schema", () => {
    const sample = {
      calendarItemIdentifier: "item-1",
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
    }
    expect(() => mcpEnrichedEventSchema.parse(sample)).not.toThrow()
  })
})

describe("bridgeCommandValidation", () => {
  it("rejects endDate before startDate", () => {
    expect(() => assertEndAfterStart(
      "2026-06-13T12:00:00.000Z",
      "2026-06-13T11:00:00.000Z",
    )).toThrow(/after startDate/)
  })

  it("requires at least one update field", () => {
    expect(() => assertUpdateHasMutableField({ eventIdentifier: "abc" }))
      .toThrow(/at least one mutable field/)
    expect(() => assertUpdateHasMutableField({ eventIdentifier: "abc", title: "New" }))
      .not.toThrow()
  })
})
