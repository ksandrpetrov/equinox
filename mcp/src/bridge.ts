import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, isAbsolute, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import type { BridgeResponse } from "./types.js"
import { requireBridgeData as validateBridgeData } from "./bridgeValidation.js"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

const defaultBridgePath = resolve(
  repoRoot,
  "build/DerivedData/Build/Products/Release/equinox-bridge",
)

export class BridgeNotFoundError extends Error {
  constructor(path: string) {
    super(
      `equinox-bridge not found at ${path}. Run ./scripts/build-mcp.sh to build the EventKit bridge.`,
    )
    this.name = "BridgeNotFoundError"
  }
}

export class BridgeInvocationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "BridgeInvocationError"
  }
}

export function resolveBridgePath(): string {
  const configured = process.env.EQUINOX_BRIDGE_PATH
  const candidate = configured
    ? isAbsolute(configured)
      ? configured
      : resolve(repoRoot, configured)
    : defaultBridgePath
  if (!existsSync(candidate)) {
    throw new BridgeNotFoundError(candidate)
  }
  return candidate
}

export function invokeBridge<T>(command: Record<string, unknown>): BridgeResponse<T> {
  const bridgePath = resolveBridgePath()
  const payload = JSON.stringify(command)
  const result = spawnSync(bridgePath, [payload], {
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  })

  if (result.error) {
    throw new BridgeInvocationError(result.error.message)
  }
  if (result.status !== 0 && result.status !== 1) {
    throw new BridgeInvocationError(
      `equinox-bridge exited with code ${result.status ?? "unknown"}: ${result.stderr || result.stdout}`,
    )
  }

  const stdout = result.stdout?.trim()
  if (!stdout) {
    throw new BridgeInvocationError("equinox-bridge returned empty output")
  }

  let parsed: BridgeResponse<T>
  try {
    parsed = JSON.parse(stdout) as BridgeResponse<T>
  } catch {
    throw new BridgeInvocationError(`equinox-bridge returned invalid JSON: ${stdout}`)
  }

  return parsed
}

export function requireBridgeData<T>(response: BridgeResponse<T>): T {
  try {
    return validateBridgeData(response)
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown bridge error"
    throw new BridgeInvocationError(message)
  }
}

export function repoRootPath(): string {
  return repoRoot
}
