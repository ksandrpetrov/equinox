import { describe, expect, it } from "vitest"

import {
  createEventInputSchema,
  listEventsInputSchema,
  listPlaudRecordingsInputSchema,
  updateEventInputSchema,
} from "../src/schemas/toolInputs.js"
import { scheduleAnalysisOutputSchema } from "../src/schemas/outputs.js"
import { analyzeSchedule } from "../src/analytics/schedule.js"

describe("tool input schemas", () => {
  it("rejects invalid calendar dates", () => {
    expect(() => listEventsInputSchema.parse({
      startDate: "2026-02-31",
      endDate: "2026-03-01",
    })).toThrow()
  })

  it("rejects endDate before startDate", () => {
    expect(() => listEventsInputSchema.parse({
      startDate: "2026-06-10",
      endDate: "2026-06-09",
    })).toThrow()
  })

  it("rejects invalid URLs in create_event", () => {
    expect(() => createEventInputSchema.parse({
      title: "Meet",
      startDate: "2026-06-13T10:00:00.000Z",
      endDate: "2026-06-13T11:00:00.000Z",
      url: "not-a-url",
    })).toThrow()
  })

  it("rejects endDate before startDate in create_event", () => {
    expect(() => createEventInputSchema.parse({
      title: "Meet",
      startDate: "2026-06-13T12:00:00.000Z",
      endDate: "2026-06-13T11:00:00.000Z",
    })).toThrow()
  })

  it("rejects update_event without mutable fields", () => {
    expect(() => updateEventInputSchema.parse({
      eventIdentifier: "evt-1",
    })).toThrow(/at least one mutable field/)
  })

  it("accepts update_event with a mutable field", () => {
    expect(() => updateEventInputSchema.parse({
      eventIdentifier: "evt-1",
      title: "Updated",
    })).not.toThrow()
  })

  it("rejects mixing date and endDate in list_plaud_recordings", () => {
    expect(() => listPlaudRecordingsInputSchema.parse({
      date: "2026-06-01",
      endDate: "2026-06-02",
    })).toThrow()
  })
})

describe("output schemas", () => {
  it("accepts analyze_schedule output shape", () => {
    const analysis = analyzeSchedule([], "2026-06-13", "2026-06-13", false, 480)
    expect(() => scheduleAnalysisOutputSchema.parse(analysis)).not.toThrow()
  })
})
