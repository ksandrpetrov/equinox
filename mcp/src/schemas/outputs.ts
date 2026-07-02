import { z } from "zod"

import {
  bridgeCalendarSchema,
  bridgeEventSchema,
  calendarsDataSchema,
  eventsDataSchema,
  mcpEnrichedEventSchema,
  plaudEventRecordingSchema,
} from "./events.js"

export const accessStatusOutputSchema = z.object({
  status: z.string(),
  granted: z.boolean(),
})

export const accessRequestOutputSchema = z.object({
  granted: z.boolean(),
  status: z.string(),
})

export const getEventBridgeDataSchema = z.object({
  event: bridgeEventSchema,
})

export const eventOutputSchema = z.object({
  event: mcpEnrichedEventSchema,
})

export const mutationOutputSchema = z.object({
  eventIdentifier: z.string().nullable().optional(),
  calendarItemIdentifier: z.string().nullable().optional(),
})

export const dayScheduleStatsSchema = z.object({
  date: z.string(),
  timedEventCount: z.number(),
  allDayEventCount: z.number(),
  meetingWithJoinUrlCount: z.number(),
  busyMinutes: z.number(),
  workMinutes: z.number(),
  busyPercent: z.number(),
})

export const scheduleAnalysisOutputSchema = z.object({
  startDate: z.string(),
  endDate: z.string(),
  totalEvents: z.number(),
  truncated: z.boolean(),
  timedEventCount: z.number(),
  allDayEventCount: z.number(),
  meetingWithJoinUrlCount: z.number(),
  totalBusyMinutes: z.number(),
  days: z.array(dayScheduleStatsSchema),
  byCalendar: z.array(
    z.object({
      calendarIdentifier: z.string(),
      calendarTitle: z.string(),
      eventCount: z.number(),
      busyMinutes: z.number(),
    }),
  ),
})

export const conflictGroupOutputSchema = z.object({
  start: z.string(),
  end: z.string(),
  events: z.array(bridgeEventSchema),
})

export const findConflictsOutputSchema = z.object({
  startDate: z.string(),
  endDate: z.string(),
  truncated: z.boolean(),
  conflictGroups: z.array(conflictGroupOutputSchema),
})

export const freeTimeSlotOutputSchema = z.object({
  start: z.string(),
  end: z.string(),
  durationMinutes: z.number(),
})

export const findFreeTimeOutputSchema = z.object({
  startDate: z.string(),
  endDate: z.string(),
  truncated: z.boolean(),
  workStart: z.string(),
  workEnd: z.string(),
  minDurationMinutes: z.number(),
  slots: z.array(freeTimeSlotOutputSchema),
})

export const plaudCatalogStatusSchema = z.object({
  available: z.boolean(),
  recordCount: z.number(),
  expectedSchemaVersion: z.number(),
  schemaVersion: z.number().optional(),
  fetchedAt: z.string().optional(),
  fingerprint: z.string().optional(),
  reason: z.string().optional(),
})

export const plaudMatchCacheStatusSchema = z.object({
  available: z.boolean(),
  positiveMatchCount: z.number(),
  negativeMatchCount: z.number(),
  fingerprint: z.string().optional(),
  reason: z.string().optional(),
})

export const plaudStatusOutputSchema = z.object({
  catalog: plaudCatalogStatusSchema,
  matchCache: plaudMatchCacheStatusSchema,
})

export const plaudEventMatchSchema = z.object({
  eventIdentifier: z.string(),
  eventStartDate: z.string(),
  fileID: z.string(),
  webURL: z.string(),
  source: z.string(),
  matchedAt: z.string().optional(),
})

export const plaudRecordingOutputSchema = z.object({
  fileID: z.string(),
  title: z.string(),
  recordedAt: z.string(),
  endDate: z.string(),
  durationSeconds: z.number(),
  webURL: z.string(),
  matchedEvents: z.array(plaudEventMatchSchema),
})

export const plaudRecordingsOutputSchema = plaudStatusOutputSchema.extend({
  startDate: z.string(),
  endDate: z.string(),
  count: z.number(),
  totalMatching: z.number(),
  truncated: z.boolean(),
  recordings: z.array(plaudRecordingOutputSchema),
})

export {
  bridgeCalendarSchema,
  bridgeEventSchema,
  calendarsDataSchema,
  eventsDataSchema,
  mcpEnrichedEventSchema,
  plaudEventRecordingSchema,
}
