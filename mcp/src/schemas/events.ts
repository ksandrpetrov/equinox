import { z } from "zod"

export const bridgeCalendarSchema = z.object({
  id: z.string(),
  title: z.string(),
  sourceTitle: z.string(),
  sourceIdentifier: z.string(),
  colorHex: z.string(),
  allowsContentModifications: z.boolean(),
  isSubscribed: z.boolean(),
  type: z.string(),
})

export const plaudEventRecordingSchema = z.object({
  fileID: z.string(),
  webURL: z.string(),
  source: z.string(),
  matchedAt: z.string().optional(),
  title: z.string().optional(),
  recordedAt: z.string().optional(),
  endDate: z.string().optional(),
  durationSeconds: z.number().optional(),
})

/** EventKit fields returned by equinox-bridge (no MCP enrichment). */
export const bridgeEventSchema = z.object({
  eventIdentifier: z.string().nullable().optional(),
  calendarItemIdentifier: z.string(),
  title: z.string(),
  location: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  url: z.string().nullable().optional(),
  startDate: z.string(),
  endDate: z.string(),
  isAllDay: z.boolean(),
  joinURL: z.string().nullable().optional(),
  calendarIdentifier: z.string(),
  calendarTitle: z.string(),
  calendarColorHex: z.string(),
  allowsContentModifications: z.boolean(),
  hasAttendees: z.boolean(),
  participationStatus: z.string().nullable().optional(),
})

/** MCP tool output after optional Plaud cache enrichment. */
export const mcpEnrichedEventSchema = bridgeEventSchema.extend({
  hasPlaudRecording: z.boolean().optional(),
  plaudRecording: plaudEventRecordingSchema.nullable().optional(),
})

export const calendarsDataSchema = z.object({
  calendars: z.array(bridgeCalendarSchema),
})

export const eventsDataSchema = z.object({
  events: z.array(mcpEnrichedEventSchema),
  truncated: z.boolean(),
})
