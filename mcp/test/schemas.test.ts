import { describe, expect, it } from "vitest"

import { bridgeEventSchema, calendarsDataSchema } from "../src/schemas/index.js"

describe("bridge schemas", () => {
  it("accepts sample calendar payload", () => {
    const parsed = calendarsDataSchema.parse({
      calendars: [
        {
          id: "cal-1",
          title: "Work",
          sourceTitle: "Google",
          sourceIdentifier: "src-1",
          colorHex: "#FF0000",
          allowsContentModifications: true,
          isSubscribed: false,
          type: "caldav",
        },
      ],
    })
    expect(parsed.calendars).toHaveLength(1)
  })

  it("accepts participationStatus on events", () => {
    const parsed = bridgeEventSchema.parse({
      eventIdentifier: "evt-1",
      calendarItemIdentifier: "item-1",
      title: "Sync",
      location: null,
      notes: null,
      url: null,
      startDate: "2026-06-14T10:00:00.000Z",
      endDate: "2026-06-14T11:00:00.000Z",
      isAllDay: false,
      joinURL: null,
      calendarIdentifier: "cal-1",
      calendarTitle: "Work",
      calendarColorHex: "#FF0000",
      allowsContentModifications: true,
      hasAttendees: true,
      participationStatus: "accepted",
    })
    expect(parsed.participationStatus).toBe("accepted")
  })
})
