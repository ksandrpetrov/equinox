import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { readFile } from "node:fs/promises"
import { request } from "node:http"
import { homedir } from "node:os"
import { dirname, isAbsolute, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import type { BridgeResponse } from "./types.js"
import { requireBridgeData as validateBridgeData } from "./bridgeValidation.js"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

const defaultBridgePath = resolve(
  repoRoot,
  "build/DerivedData/Build/Products/Release/equinox-bridge",
)
const defaultAppBridgeStatePath = resolve(
  homedir(),
  "Library/Application Support/com.equinox.equinoxApp/mcp-app-bridge.json",
)

type AppBridgeState = {
  url: string
  token: string
  pid?: number
}

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

export async function invokeBridge<T>(command: Record<string, unknown>): Promise<BridgeResponse<T>> {
  const appBridgeResponse = await invokeAppBridge<T>(command)
  if (appBridgeResponse) {
    return appBridgeResponse
  }
  return invokeBridgeProcess(command)
}

function invokeBridgeProcess<T>(command: Record<string, unknown>): BridgeResponse<T> {
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

async function invokeAppBridge<T>(
  command: Record<string, unknown>,
): Promise<BridgeResponse<T> | undefined> {
  const state = await readAppBridgeState()
  if (!state) {
    logAppBridgeFallback("app bridge state file missing or invalid")
    return undefined
  }

  try {
    return await postAppBridge<T>(state, command)
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error)
    logAppBridgeFallback(reason)
    return undefined
  }
}

function logAppBridgeFallback(reason: string): void {
  if (!isBridgeDebugEnabled()) {
    return
  }
  console.error(`[equinox-mcp] falling back to equinox-bridge CLI: ${reason}`)
}

function isBridgeDebugEnabled(): boolean {
  const flag = process.env.EQUINOX_BRIDGE_DEBUG
  return flag === "1" || flag === "true"
}

async function readAppBridgeState(): Promise<AppBridgeState | undefined> {
  const statePath = process.env.EQUINOX_APP_BRIDGE_STATE_PATH ?? defaultAppBridgeStatePath
  try {
    const raw = await readFile(statePath, "utf8")
    const parsed = JSON.parse(raw) as Partial<AppBridgeState>
    if (typeof parsed.url !== "string" || typeof parsed.token !== "string") {
      return undefined
    }
    return { url: parsed.url, token: parsed.token, pid: parsed.pid }
  } catch {
    return undefined
  }
}

function postAppBridge<T>(
  state: AppBridgeState,
  command: Record<string, unknown>,
): Promise<BridgeResponse<T>> {
  return new Promise((resolvePromise, reject) => {
    const url = new URL(state.url)
    if (!["127.0.0.1", "localhost"].includes(url.hostname)) {
      reject(new BridgeInvocationError("Equinox app bridge must use localhost."))
      return
    }

    const payload = JSON.stringify(command)
    const appRequest = request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: "POST",
        headers: {
          "Authorization": `Bearer ${state.token}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
        timeout: 2_000,
      },
      (response) => {
        const chunks: Buffer[] = []
        response.on("data", (chunk: Buffer) => chunks.push(chunk))
        response.on("end", () => {
          const body = Buffer.concat(chunks).toString("utf8").trim()
          if (!body) {
            reject(new BridgeInvocationError("Equinox app bridge returned empty output"))
            return
          }
          try {
            resolvePromise(JSON.parse(body) as BridgeResponse<T>)
          } catch {
            reject(new BridgeInvocationError(`Equinox app bridge returned invalid JSON: ${body}`))
          }
        })
      },
    )

    appRequest.on("timeout", () => {
      appRequest.destroy(new BridgeInvocationError("Equinox app bridge timed out"))
    })
    appRequest.on("error", reject)
    appRequest.write(payload)
    appRequest.end()
  })
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
