import { describe, expect, it, vi } from "vitest"

import { fetchBridgeEventsForRange } from "../src/tools/eventBridgeFetch.js"

vi.mock("../src/bridge.js", () => ({
  invokeBridge: vi.fn(),
  requireBridgeData: vi.fn((_response, _schema) => ({
    events: [{
      eventIdentifier: "evt-1",
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
    }],
    truncated: false,
  })),
}))

describe("fetchBridgeEventsForRange", () => {
  it("invokes list_events with range and limit", async () => {
    const { invokeBridge } = await import("../src/bridge.js")
    const data = await fetchBridgeEventsForRange({
      startDate: "2026-06-13",
      endDate: "2026-06-14",
      calendarIds: ["cal-1"],
    }, 250)

    expect(invokeBridge).toHaveBeenCalledWith({
      command: "list_events",
      startDate: "2026-06-13",
      endDate: "2026-06-14",
      calendarIds: ["cal-1"],
      limit: 250,
    })
    expect(data.events).toHaveLength(1)
    expect(data.truncated).toBe(false)
  })
})
