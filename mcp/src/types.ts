import type { z } from "zod"

import {
  bridgeCalendarSchema,
  bridgeEventSchema,
  calendarsDataSchema,
  eventsDataSchema,
} from "./schemas/events.js"

export type BridgeError = {
  code: string
  message: string
}

export type BridgeResponse<T = unknown> = {
  ok: boolean
  data?: T
  error?: BridgeError
}

export type BridgeCalendar = z.infer<typeof bridgeCalendarSchema>
export type BridgeEvent = z.infer<typeof bridgeEventSchema>

export type AccessStatusData = {
  status: string
  granted: boolean
}

export type AccessRequestData = {
  granted: boolean
  status: string
}

export type CalendarsData = z.infer<typeof calendarsDataSchema>
export type EventsData = z.infer<typeof eventsDataSchema>

export type EventData = {
  event: BridgeEvent
}

export type MutationData = {
  eventIdentifier: string | null
  calendarItemIdentifier: string | null
}
