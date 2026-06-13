import { describe, expect, it } from "vitest"

import { analyzeSchedule, findConflicts, findFreeTime } from "../src/analytics/schedule.js"
import type { BridgeEvent } from "../src/types.js"

function event(overrides: Partial<BridgeEvent> & Pick<BridgeEvent, "title" | "startDate" | "endDate">): BridgeEvent {
  return {
    eventIdentifier: "evt-1",
    calendarItemIdentifier: "item-1",
    location: null,
    notes: null,
    url: null,
    isAllDay: false,
    joinURL: null,
    calendarIdentifier: "cal-1",
    calendarTitle: "Work",
    calendarColorHex: "#FF0000",
    allowsContentModifications: true,
    hasAttendees: false,
    ...overrides,
  }
}

describe("analyzeSchedule", () => {
  it("counts busy minutes and meetings with join URL", () => {
    const events = [
      event({
        title: "Standup",
        startDate: "2026-06-13T09:00:00.000Z",
        endDate: "2026-06-13T09:30:00.000Z",
        joinURL: "https://meet.google.com/abc",
      }),
      event({
        title: "Focus",
        startDate: "2026-06-13T11:00:00.000Z",
        endDate: "2026-06-13T12:00:00.000Z",
      }),
      event({
        title: "Holiday",
        startDate: "2026-06-13T00:00:00.000Z",
        endDate: "2026-06-13T23:59:59.000Z",
        isAllDay: true,
      }),
    ]

    const analysis = analyzeSchedule(events, "2026-06-13", "2026-06-13", false, 480)
    expect(analysis.timedEventCount).toBe(2)
    expect(analysis.allDayEventCount).toBe(1)
    expect(analysis.meetingWithJoinUrlCount).toBe(1)
    expect(analysis.totalBusyMinutes).toBeGreaterThan(0)
    expect(analysis.days).toHaveLength(1)
    expect(analysis.byCalendar[0].eventCount).toBe(3)
  })
})

describe("findConflicts", () => {
  it("groups overlapping timed events", () => {
    const events = [
      event({
        title: "A",
        startDate: "2026-06-13T10:00:00.000Z",
        endDate: "2026-06-13T11:00:00.000Z",
      }),
      event({
        title: "B",
        startDate: "2026-06-13T10:30:00.000Z",
        endDate: "2026-06-13T11:30:00.000Z",
      }),
      event({
        title: "C",
        startDate: "2026-06-13T13:00:00.000Z",
        endDate: "2026-06-13T14:00:00.000Z",
      }),
    ]

    const conflicts = findConflicts(events)
    expect(conflicts).toHaveLength(1)
    expect(conflicts[0].events).toHaveLength(2)
  })
})

describe("findFreeTime", () => {
  it("returns free slots between busy events in work hours", () => {
    const events = [
      event({
        title: "Morning",
        startDate: "2026-06-13T09:00:00.000Z",
        endDate: "2026-06-13T10:00:00.000Z",
      }),
      event({
        title: "Afternoon",
        startDate: "2026-06-13T14:00:00.000Z",
        endDate: "2026-06-13T15:00:00.000Z",
      }),
    ]

    const slots = findFreeTime(events, "2026-06-13", "2026-06-13", "09:00", "18:00", 30)
    expect(slots.length).toBeGreaterThan(0)
    expect(slots.every((slot) => slot.durationMinutes >= 30)).toBe(true)
  })
})
