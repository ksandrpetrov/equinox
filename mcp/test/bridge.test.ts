import { describe, expect, it } from "vitest"

import { requireBridgeData } from "../src/bridge.js"
import type { AccessStatusData, BridgeResponse } from "../src/types.js"

describe("requireBridgeData", () => {
  it("returns data for successful responses", () => {
    const response: BridgeResponse<AccessStatusData> = {
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
})

describe("bridge response parsing", () => {
  it("parses ok and error envelopes", () => {
    const ok = JSON.parse('{"ok":true,"data":{"status":"full_access","granted":true}}')
    const err = JSON.parse('{"ok":false,"error":{"code":"not_found","message":"Event not found"}}')
    expect(ok.ok).toBe(true)
    expect(err.error.code).toBe("not_found")
  })
})
