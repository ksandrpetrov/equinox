import { describe, expect, it } from "vitest"

import {
  classifyNodeError,
  isMutatingBridgeCommand,
  shouldFallbackToCli,
} from "../src/bridgeFallback.js"

describe("bridge fallback policy", () => {
  it("detects mutating bridge commands", () => {
    expect(isMutatingBridgeCommand({ command: "create_event" })).toBe(true)
    expect(isMutatingBridgeCommand({ command: "list_events" })).toBe(false)
  })

  it("always falls back when app bridge state is missing", () => {
    expect(shouldFallbackToCli("state_missing", true)).toBe(true)
    expect(shouldFallbackToCli("state_missing", false)).toBe(true)
  })

  it("falls back on connection refused even for mutations", () => {
    expect(shouldFallbackToCli("connection_refused", true)).toBe(true)
  })

  it("does not fall back on timeout for mutations", () => {
    expect(shouldFallbackToCli("timeout", true)).toBe(false)
  })

  it("falls back on timeout for read-only commands", () => {
    expect(shouldFallbackToCli("timeout", false)).toBe(true)
  })

  it("falls back on pre-bridge HTTP rejections", () => {
    expect(shouldFallbackToCli("http_error", true, 401)).toBe(true)
    expect(shouldFallbackToCli("http_error", true, 500)).toBe(false)
  })

  it("classifies node connection errors", () => {
    expect(classifyNodeError(Object.assign(new Error("refused"), { code: "ECONNREFUSED" })))
      .toBe("connection_refused")
    expect(classifyNodeError(new Error("Equinox app bridge timed out"))).toBe("timeout")
  })
})
