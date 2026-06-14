import { z } from "zod"

import {
  bridgeCalendarSchema,
  bridgeEventSchema,
  calendarsDataSchema,
  eventsDataSchema,
} from "./schemas/events.js"
import type { BridgeResponse } from "./types.js"

const accessStatusDataSchema = z.object({
  status: z.string(),
  granted: z.boolean(),
})

const accessRequestDataSchema = z.object({
  granted: z.boolean(),
  status: z.string(),
})

const eventDataSchema = z.object({
  event: bridgeEventSchema,
})

const mutationDataSchema = z.object({
  eventIdentifier: z.string().nullable().optional(),
  calendarItemIdentifier: z.string().nullable().optional(),
})

const bridgeDataSchema = z.union([
  accessStatusDataSchema,
  accessRequestDataSchema,
  calendarsDataSchema,
  eventsDataSchema,
  eventDataSchema,
  mutationDataSchema,
])

export function requireBridgeData<T>(response: BridgeResponse<T>): T {
  if (!response.ok || response.data === undefined) {
    const message = response.error?.message ?? "Unknown bridge error"
    const code = response.error?.code ?? "bridge_error"
    throw new Error(`${code}: ${message}`)
  }

  const parsed = bridgeDataSchema.safeParse(response.data)
  if (!parsed.success) {
    throw new Error(`bridge_invalid_response: ${parsed.error.message}`)
  }

  return response.data
}

export {
  accessRequestDataSchema,
  accessStatusDataSchema,
  bridgeCalendarSchema,
  bridgeEventSchema,
  bridgeDataSchema,
  calendarsDataSchema,
  eventDataSchema,
  eventsDataSchema,
  mutationDataSchema,
}
