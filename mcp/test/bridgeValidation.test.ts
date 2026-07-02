import { describe, expect, it } from "vitest"
import { z } from "zod"

import { requireBridgeData } from "../src/bridgeValidation.js"
import { eventsDataSchema } from "../src/schemas/outputs.js"
import type { BridgeResponse } from "../src/types.js"

describe("requireBridgeData", () => {
  it("returns data for successful responses", () => {
    const response: BridgeResponse = {
      ok: true,
      data: { status: "full_access", granted: true },
    }
    expect(requireBridgeData(response)).toEqual({ status: "full_access", granted: true })
  })

  it("throws for bridge errors", () => {
    const response: BridgeResponse = {
      ok: false,
      error: { code: "access_denied", message: "Calendar access not granted" },
    }
    expect(() => requireBridgeData(response)).toThrow("access_denied: Calendar access not granted")
  })

  it("validates payloads against per-command schemas", () => {
    const response: BridgeResponse = {
      ok: true,
      data: { events: [], truncated: false },
    }
    expect(() => requireBridgeData(response, eventsDataSchema)).not.toThrow()
  })

  it("rejects malformed event payloads", () => {
    const response: BridgeResponse = {
      ok: true,
      data: { events: [{ title: "broken" }], truncated: false },
    }
    expect(() => requireBridgeData(response, eventsDataSchema)).toThrow("bridge_invalid_response")
  })

  it("rejects mutation-shaped payloads for event list responses", () => {
    const response: BridgeResponse = {
      ok: true,
      data: { eventIdentifier: "evt-1" },
    }
    expect(() => requireBridgeData(response, eventsDataSchema)).toThrow("bridge_invalid_response")
  })

  it("accepts mutation payloads only with the mutation schema", () => {
    const response: BridgeResponse = {
      ok: true,
      data: { eventIdentifier: "evt-1", calendarItemIdentifier: "item-1" },
    }
    const mutationSchema = z.object({
      eventIdentifier: z.string().nullable().optional(),
      calendarItemIdentifier: z.string().nullable().optional(),
    })
    expect(requireBridgeData(response, mutationSchema)).toEqual({
      eventIdentifier: "evt-1",
      calendarItemIdentifier: "item-1",
    })
  })
})
