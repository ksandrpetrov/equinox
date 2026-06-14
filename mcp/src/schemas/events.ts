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

export const bridgeEventSchema = z.object({
  eventIdentifier: z.string().nullable(),
  calendarItemIdentifier: z.string(),
  title: z.string(),
  location: z.string().nullable(),
  notes: z.string().nullable(),
  url: z.string().nullable(),
  startDate: z.string(),
  endDate: z.string(),
  isAllDay: z.boolean(),
  joinURL: z.string().nullable(),
  calendarIdentifier: z.string(),
  calendarTitle: z.string(),
  calendarColorHex: z.string(),
  allowsContentModifications: z.boolean(),
  hasAttendees: z.boolean(),
  participationStatus: z.string().nullable().optional(),
})

export const calendarsDataSchema = z.object({
  calendars: z.array(bridgeCalendarSchema),
})

export const eventsDataSchema = z.object({
  events: z.array(bridgeEventSchema),
  truncated: z.boolean(),
})
