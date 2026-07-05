import { z } from "zod"

import { bridgeUpdateMutableFields } from "../bridgeCommandValidation.js"
import {
  assertAnalyticsDateRange,
  calendarDateSchema,
  datePattern,
  endDateAfterStartDate,
  endDateOnOrAfterStartDate,
  eventDateInputSchema,
  optionalUrlSchema,
  timePattern,
} from "./dates.js"

export {
  assertAnalyticsDateRange,
  calendarDateSchema,
  calendarDayCount,
  datePattern,
  endDateAfterStartDate,
  endDateOnOrAfterStartDate,
  eventDateInputSchema,
  isValidCalendarDate,
  maxAnalyticsRangeDays,
  optionalUrlSchema,
  parseCalendarDate,
  timePattern,
} from "./dates.js"

const dateRangeRefine = (input: { startDate: string; endDate: string }) =>
  endDateOnOrAfterStartDate(input.startDate, input.endDate)

export const listEventsInputSchema = z.object({
  startDate: calendarDateSchema,
  endDate: calendarDateSchema,
  calendarIds: z.array(z.string().min(1)).optional(),
  limit: z.number().int().positive().max(500).optional(),
  includePlaud: z.boolean().optional(),
}).refine(dateRangeRefine, {
  message: "endDate must be on or after startDate.",
  path: ["endDate"],
})

export const getEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
})

export const createEventInputSchema = z.object({
  title: z.string().trim().min(1),
  startDate: eventDateInputSchema,
  endDate: eventDateInputSchema,
  calendarId: z.string().min(1).optional(),
  allDay: z.boolean().optional(),
  location: z.string().optional(),
  notes: z.string().optional(),
  url: optionalUrlSchema,
}).refine((input) => endDateAfterStartDate(input.startDate, input.endDate), {
  message: "endDate must be after startDate.",
  path: ["endDate"],
})

export const updateEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
  title: z.string().trim().min(1).optional(),
  startDate: eventDateInputSchema.optional(),
  endDate: eventDateInputSchema.optional(),
  calendarId: z.string().min(1).optional(),
  allDay: z.boolean().optional(),
  location: z.string().optional(),
  notes: z.string().optional(),
  url: optionalUrlSchema,
}).refine(
  (input) => !input.startDate || !input.endDate || endDateAfterStartDate(input.startDate, input.endDate),
  {
    message: "endDate must be after startDate when both are provided.",
    path: ["endDate"],
  },
).refine(
  (input) => bridgeUpdateMutableFields.some((key) => input[key as keyof typeof input] !== undefined),
  {
    message: "update_event requires at least one mutable field.",
    path: ["eventIdentifier"],
  },
)

export const deleteEventInputSchema = z.object({
  eventIdentifier: z.string().min(1),
  span: z.enum(["thisEvent", "futureEvents"]).optional(),
})

export const analyzeScheduleInputSchema = z.object({
  startDate: calendarDateSchema,
  endDate: calendarDateSchema,
  calendarIds: z.array(z.string().min(1)).optional(),
  workMinutesPerDay: z.number().int().positive().max(24 * 60).optional(),
}).refine(dateRangeRefine, {
  message: "endDate must be on or after startDate.",
  path: ["endDate"],
})

export const findConflictsInputSchema = z.object({
  startDate: calendarDateSchema,
  endDate: calendarDateSchema,
  calendarIds: z.array(z.string().min(1)).optional(),
}).refine(dateRangeRefine, {
  message: "endDate must be on or after startDate.",
  path: ["endDate"],
})

export const findFreeTimeInputSchema = z.object({
  startDate: calendarDateSchema,
  endDate: calendarDateSchema,
  calendarIds: z.array(z.string().min(1)).optional(),
  workStart: z.string().regex(timePattern).optional(),
  workEnd: z.string().regex(timePattern).optional(),
  minDurationMinutes: z.number().int().positive().max(24 * 60).optional(),
}).refine(dateRangeRefine, {
  message: "endDate must be on or after startDate.",
  path: ["endDate"],
}).refine(
  (input) => {
    const workStart = input.workStart ?? "09:00"
    const workEnd = input.workEnd ?? "18:00"
    return workEnd > workStart
  },
  {
    message: "workEnd must be after workStart.",
    path: ["workEnd"],
  },
)

export const listPlaudRecordingsInputSchema = z.object({
  date: calendarDateSchema.optional(),
  startDate: calendarDateSchema.optional(),
  endDate: calendarDateSchema.optional(),
  limit: z.number().int().positive().max(500).optional(),
}).refine((input) => input.date || input.startDate, {
  message: "Provide either date or startDate.",
}).refine((input) => !(input.date && input.endDate), {
  message: "Provide either date or startDate/endDate, not both.",
  path: ["endDate"],
}).refine(
  (input) => !input.startDate || !input.endDate || endDateOnOrAfterStartDate(input.startDate, input.endDate),
  {
    message: "endDate must be on or after startDate.",
    path: ["endDate"],
  },
)
