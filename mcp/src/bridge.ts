import { execFile } from "node:child_process"
import { existsSync } from "node:fs"
import { readFile } from "node:fs/promises"
import { request } from "node:http"
import { homedir } from "node:os"
import { dirname, isAbsolute, resolve } from "node:path"
import { promisify } from "node:util"
import { fileURLToPath } from "node:url"

import type { z } from "zod"

import {
  classifyNodeError,
  isMutatingBridgeCommand,
  shouldFallbackToCli,
  type AppBridgeFailureKind,
} from "./bridgeFallback.js"
import { requireBridgeData as validateBridgeData } from "./bridgeValidation.js"
import type { BridgeResponse } from "./types.js"

const execFileAsync = promisify(execFile)

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

const defaultBridgePath = resolve(
  repoRoot,
  "build/DerivedData/Build/Products/Release/equinox-bridge",
)
const defaultAppBridgeStatePath = resolve(
  homedir(),
  "Library/Application Support/com.equinox.equinoxApp/mcp-app-bridge.json",
)

const defaultAppBridgeTimeoutMs = 30_000
const defaultCliTimeoutMs = 60_000

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

async function invokeBridgeProcess<T>(command: Record<string, unknown>): Promise<BridgeResponse<T>> {
  const bridgePath = resolveBridgePath()
  const payload = JSON.stringify(command)
  const isAccessRequest = command.command === "request_access"
  try {
    const result = await execFileAsync(bridgePath, [payload], {
      encoding: "utf8",
      maxBuffer: 16 * 1024 * 1024,
      timeout: isAccessRequest ? undefined : defaultCliTimeoutMs,
    })

    const stdout = result.stdout?.trim()
    if (!stdout) {
      throw new BridgeInvocationError("equinox-bridge returned empty output")
    }

    try {
      return JSON.parse(stdout) as BridgeResponse<T>
    } catch {
      throw new BridgeInvocationError(`equinox-bridge returned invalid JSON: ${stdout}`)
    }
  } catch (error) {
    if (error instanceof BridgeInvocationError) {
      throw error
    }
    const execError = error as NodeJS.ErrnoException & { stdout?: string; status?: number }
    if (execError.stdout?.trim()) {
      try {
        return JSON.parse(execError.stdout.trim()) as BridgeResponse<T>
      } catch {
        // Fall through to generic error handling.
      }
    }
    const message = execError.message || "equinox-bridge invocation failed"
    throw new BridgeInvocationError(message)
  }
}

async function invokeAppBridge<T>(
  command: Record<string, unknown>,
): Promise<BridgeResponse<T> | undefined> {
  const state = await readAppBridgeState()
  if (!state) {
    logAppBridgeFallback("app bridge state file missing or invalid", command, "state_missing")
    return undefined
  }

  try {
    return await postAppBridge<T>(state, command)
  } catch (error) {
    const isMutating = isMutatingBridgeCommand(command)
    const httpStatus = error instanceof AppBridgeHttpError ? error.statusCode : undefined
    const failure = error instanceof AppBridgeHttpError
      ? "http_error"
      : classifyNodeError(error)
    if (shouldFallbackToCli(failure, isMutating, httpStatus)) {
      const reason = error instanceof Error ? error.message : String(error)
      logAppBridgeFallback(reason, command, failure)
      return undefined
    }
    if (error instanceof Error) {
      throw new BridgeInvocationError(
        isMutating
          ? `${error.message} (mutation was not retried via CLI to avoid duplicates)`
          : error.message,
      )
    }
    throw new BridgeInvocationError(String(error))
  }
}

class AppBridgeHttpError extends Error {
  readonly statusCode: number

  constructor(statusCode: number, message: string) {
    super(message)
    this.name = "AppBridgeHttpError"
    this.statusCode = statusCode
  }
}

function logAppBridgeFallback(
  reason: string,
  command: Record<string, unknown>,
  failure: AppBridgeFailureKind,
): void {
  const isMutating = isMutatingBridgeCommand(command)
  if (!isMutating && !isBridgeDebugEnabled()) {
    return
  }
  const commandName = typeof command.command === "string" ? command.command : "unknown"
  console.error(
    `[equinox-mcp] falling back to equinox-bridge CLI (${commandName}, ${failure}): ${reason}`,
  )
}

function isBridgeDebugEnabled(): boolean {
  const flag = process.env.EQUINOX_BRIDGE_DEBUG
  return flag === "1" || flag === "true"
}

function appBridgeTimeoutMs(): number {
  const configured = process.env.EQUINOX_APP_BRIDGE_TIMEOUT_MS
  if (!configured) {
    return defaultAppBridgeTimeoutMs
  }
  const parsed = Number(configured)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : defaultAppBridgeTimeoutMs
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
        timeout: appBridgeTimeoutMs(),
      },
      (response) => {
        const chunks: Buffer[] = []
        response.on("data", (chunk: Buffer) => chunks.push(chunk))
        response.on("end", () => {
          const body = Buffer.concat(chunks).toString("utf8").trim()
          const statusCode = response.statusCode ?? 0
          if (statusCode !== 200) {
            reject(new AppBridgeHttpError(statusCode, `Equinox app bridge HTTP ${statusCode}: ${body || "empty body"}`))
            return
          }
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

export function requireBridgeData<T>(
  response: BridgeResponse<T>,
  schema?: z.ZodType<T>,
): T {
  try {
    if (schema) {
      return validateBridgeData(response as BridgeResponse<unknown>, schema)
    }
    return validateBridgeData(response)
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown bridge error"
    throw new BridgeInvocationError(message)
  }
}

export function repoRootPath(): string {
  return repoRoot
}
