import { z } from "zod"

export const datePattern = /^\d{4}-\d{2}-\d{2}$/
export const timePattern = /^\d{2}:\d{2}$/

export const listEventsInputSchema = z.object({
  startDate: z.string().regex(datePattern),
  endDate: z.string().regex(datePattern),
  calendarIds: z.array(z.string().min(1)).optional(),
  limit: z.number().int().positive().max(500).optional(),
  includePlaud: z.boolean().optional(),
})

export const getEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
})

export const createEventInputSchema = z.object({
  title: z.string().min(1),
  startDate: z.string().min(1),
  endDate: z.string().min(1),
  calendarId: z.string().min(1).optional(),
  allDay: z.boolean().optional(),
  location: z.string().optional(),
  notes: z.string().optional(),
  url: z.string().optional(),
})

export const updateEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
  title: z.string().min(1).optional(),
  startDate: z.string().min(1).optional(),
  endDate: z.string().min(1).optional(),
  calendarId: z.string().min(1).optional(),
  allDay: z.boolean().optional(),
  location: z.string().optional(),
  notes: z.string().optional(),
  url: z.string().optional(),
})

export const deleteEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
  span: z.enum(["thisEvent", "futureEvents"]).optional(),
})

export const analyzeScheduleInputSchema = z.object({
  startDate: z.string().regex(datePattern),
  endDate: z.string().regex(datePattern),
  calendarIds: z.array(z.string().min(1)).optional(),
  workMinutesPerDay: z.number().int().positive().max(24 * 60).optional(),
})

export const findConflictsInputSchema = z.object({
  startDate: z.string().regex(datePattern),
  endDate: z.string().regex(datePattern),
  calendarIds: z.array(z.string().min(1)).optional(),
})

export const findFreeTimeInputSchema = z.object({
  startDate: z.string().regex(datePattern),
  endDate: z.string().regex(datePattern),
  calendarIds: z.array(z.string().min(1)).optional(),
  workStart: z.string().regex(timePattern).optional(),
  workEnd: z.string().regex(timePattern).optional(),
  minDurationMinutes: z.number().int().positive().max(24 * 60).optional(),
})

export const listPlaudRecordingsInputSchema = z.object({
  date: z.string().regex(datePattern).optional(),
  startDate: z.string().regex(datePattern).optional(),
  endDate: z.string().regex(datePattern).optional(),
  limit: z.number().int().positive().max(500).optional(),
}).refine((input) => input.date || input.startDate, {
  message: "Provide either date or startDate.",
})
