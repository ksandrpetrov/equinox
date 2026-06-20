import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { requireBridgeData } from "../src/bridge.js"
import type { AccessStatusData, BridgeResponse } from "../src/types.js"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const defaultBridgePath = resolve(
  repoRoot,
  "build/DerivedData/Build/Products/Release/equinox-bridge",
)

function resolveBridgeExecutable(): string | undefined {
  const configured = process.env.EQUINOX_BRIDGE_PATH
  const candidate = configured ? resolve(repoRoot, configured) : defaultBridgePath
  return existsSync(candidate) ? candidate : undefined
}

function invokeBridge(command: Record<string, unknown>): BridgeResponse {
  const bridgePath = resolveBridgeExecutable()
  if (!bridgePath) {
    throw new Error("equinox-bridge binary not found")
  }

  const result = spawnSync(bridgePath, [JSON.stringify(command)], {
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
  })

  const stdout = result.stdout?.trim()
  if (!stdout) {
    throw new Error(`equinox-bridge returned empty output (status ${result.status})`)
  }

  return JSON.parse(stdout) as BridgeResponse
}

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

function bridgeHasCalendarAccess(): boolean {
  const response = invokeBridge({ command: "access_status" })
  return response.ok === true && response.data?.granted === true
}

describe("equinox-bridge contract", () => {
  const bridgePath = resolveBridgeExecutable()

  it.skipIf(!bridgePath)("access_status returns a typed envelope", () => {
    const response = invokeBridge({ command: "access_status" })
    expect(response.ok).toBe(true)
    expect(response.data).toMatchObject({
      status: expect.any(String),
      granted: expect.any(Boolean),
    })
  })

  it.skipIf(!bridgePath)("unknown_command returns invalid_request-style failure", () => {
    const response = invokeBridge({ command: "not_a_real_command" })
    expect(response.ok).toBe(false)
    expect(response.error?.code).toBe("unknown_command")
  })

  it.skipIf(!bridgePath)("invalid JSON command surfaces invalid_request", () => {
    const result = spawnSync(bridgePath!, ["{not-json"], { encoding: "utf8" })
    const parsed = JSON.parse(result.stdout.trim()) as BridgeResponse
    expect(parsed.ok).toBe(false)
    expect(parsed.error?.code).toBe("invalid_request")
  })

  it.skipIf(!bridgePath || !bridgeHasCalendarAccess())("list_events without dates returns invalid_request", () => {
    const response = invokeBridge({ command: "list_events" })
    expect(response.ok).toBe(false)
    expect(response.error?.code).toBe("invalid_request")
  })

  it.skipIf(!bridgePath || !bridgeHasCalendarAccess())("get_event without identifier returns invalid_request", () => {
    const response = invokeBridge({ command: "get_event" })
    expect(response.ok).toBe(false)
    expect(response.error?.code).toBe("invalid_request")
  })

  it.skipIf(!bridgePath || !bridgeHasCalendarAccess())("delete_event without identifier returns invalid_request", () => {
    const response = invokeBridge({ command: "delete_event" })
    expect(response.ok).toBe(false)
    expect(response.error?.code).toBe("invalid_request")
  })
})
