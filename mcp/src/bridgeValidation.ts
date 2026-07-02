import type { z } from "zod"

import type { BridgeResponse } from "./types.js"

export function requireBridgeData<T>(
  response: BridgeResponse<unknown>,
  schema: z.ZodType<T>,
): T
export function requireBridgeData<T>(
  response: BridgeResponse<T>,
): T
export function requireBridgeData<T>(
  response: BridgeResponse<unknown>,
  schema?: z.ZodType<T>,
): T {
  if (!response.ok || response.data === undefined) {
    const message = response.error?.message ?? "Unknown bridge error"
    const code = response.error?.code ?? "bridge_error"
    throw new Error(`${code}: ${message}`)
  }

  if (schema) {
    const parsed = schema.safeParse(response.data)
    if (!parsed.success) {
      throw new Error(`bridge_invalid_response: ${parsed.error.message}`)
    }
    return parsed.data
  }

  return response.data as T
}
