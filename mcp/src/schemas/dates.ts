import { z } from "zod"

export const datePattern = /^\d{4}-\d{2}-\d{2}$/
export const timePattern = /^\d{2}:\d{2}$/
const isoInstantPrefixPattern = /^\d{4}-\d{2}-\d{2}T/

export const maxAnalyticsRangeDays = 366

/** Strict YYYY-MM-DD that rejects rollover dates like 2026-02-31. */
export const calendarDateSchema = z.string().regex(datePattern).refine(isValidCalendarDate, {
  message: "Expected a valid calendar date (YYYY-MM-DD)",
})

export const eventDateInputSchema = z.string().min(1).refine(
  (value) => {
    if (datePattern.test(value)) {
      return isValidCalendarDate(value)
    }
    return isoInstantPrefixPattern.test(value)
  },
  { message: "Expected YYYY-MM-DD or ISO-8601 datetime" },
)

export const optionalUrlSchema = z.url().optional()

export function isValidCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (!match) {
    return false
  }
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  const date = new Date(year, month - 1, day)
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
}

export function calendarDayCount(startDate: string, endDate: string): number {
  const start = parseCalendarDate(startDate)
  const end = parseCalendarDate(endDate)
  const msPerDay = 24 * 60 * 60 * 1000
  return Math.floor((end.getTime() - start.getTime()) / msPerDay) + 1
}

export function assertAnalyticsDateRange(startDate: string, endDate: string): void {
  if (parseCalendarDate(endDate) < parseCalendarDate(startDate)) {
    throw new Error("endDate must be on or after startDate.")
  }
  const dayCount = calendarDayCount(startDate, endDate)
  if (dayCount > maxAnalyticsRangeDays) {
    throw new Error(
      `Date range spans ${dayCount} days; analytics tools support at most ${maxAnalyticsRangeDays} days.`,
    )
  }
}

export function parseCalendarDate(value: string): Date {
  if (!isValidCalendarDate(value)) {
    throw new Error(`Invalid calendar date: ${value}`)
  }
  const [year, month, day] = value.split("-").map(Number)
  return new Date(year, month - 1, day)
}

export function endDateAfterStartDate(startDate: string, endDate: string): boolean {
  if (datePattern.test(startDate) && datePattern.test(endDate)) {
    return parseCalendarDate(endDate) > parseCalendarDate(startDate)
  }
  const start = new Date(startDate)
  const end = new Date(endDate)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return false
  }
  return end > start
}

/** Inclusive range for list/analytics queries (endDate may equal startDate). */
export function endDateOnOrAfterStartDate(startDate: string, endDate: string): boolean {
  if (datePattern.test(startDate) && datePattern.test(endDate)) {
    return parseCalendarDate(endDate) >= parseCalendarDate(startDate)
  }
  const start = new Date(startDate)
  const end = new Date(endDate)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return false
  }
  return end >= start
}
