import { describe, expect, it } from "vitest"
import { z } from "zod"

const datePattern = /^\d{4}-\d{2}-\d{2}$/

const listEventsSchema = z.object({
  startDate: z.string().regex(datePattern),
  endDate: z.string().regex(datePattern),
  calendarIds: z.array(z.string().min(1)).optional(),
  limit: z.number().int().positive().max(500).optional(),
})

const createEventSchema = z.object({
  title: z.string().min(1),
  startDate: z.string().min(1),
  endDate: z.string().min(1),
  calendarId: z.string().min(1).optional(),
  allDay: z.boolean().optional(),
  location: z.string().optional(),
  notes: z.string().optional(),
  url: z.string().optional(),
})

const deleteEventSchema = z.object({
  eventIdentifier: z.string().min(1),
  span: z.enum(["thisEvent", "futureEvents"]).optional(),
})

describe("MCP Zod schemas", () => {
  it("accepts valid list_events input", () => {
    expect(
      listEventsSchema.parse({
        startDate: "2026-06-01",
        endDate: "2026-06-30",
        limit: 100,
      }),
    ).toEqual({
      startDate: "2026-06-01",
      endDate: "2026-06-30",
      limit: 100,
    })
  })

  it("rejects invalid list_events dates", () => {
    expect(() =>
      listEventsSchema.parse({ startDate: "06-01-2026", endDate: "2026-06-30" }),
    ).toThrow()
  })

  it("accepts create_event required fields", () => {
    const parsed = createEventSchema.parse({
      title: "Standup",
      startDate: "2026-06-13T10:00:00Z",
      endDate: "2026-06-13T10:30:00Z",
    })
    expect(parsed.title).toBe("Standup")
  })

  it("accepts delete_event span enum", () => {
    expect(deleteEventSchema.parse({ eventIdentifier: "abc", span: "futureEvents" }).span).toBe(
      "futureEvents",
    )
  })
})
