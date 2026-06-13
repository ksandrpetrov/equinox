import type { BridgeEvent } from "../types.js"

export type BusyInterval = {
  start: Date
  end: Date
  event: BridgeEvent
}

export type DayScheduleStats = {
  date: string
  timedEventCount: number
  allDayEventCount: number
  meetingWithJoinUrlCount: number
  busyMinutes: number
  workMinutes: number
  busyPercent: number
}

export type ScheduleAnalysis = {
  startDate: string
  endDate: string
  totalEvents: number
  truncated: boolean
  timedEventCount: number
  allDayEventCount: number
  meetingWithJoinUrlCount: number
  totalBusyMinutes: number
  days: DayScheduleStats[]
  byCalendar: Array<{
    calendarIdentifier: string
    calendarTitle: string
    eventCount: number
    busyMinutes: number
  }>
}

export type ConflictGroup = {
  start: string
  end: string
  events: BridgeEvent[]
}

export type FreeTimeSlot = {
  start: string
  end: string
  durationMinutes: number
}

const dayKeyFormatter = new Intl.DateTimeFormat("en-CA", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
})

function parseInstant(value: string): Date {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid date: ${value}`)
  }
  return parsed
}

function dayKey(date: Date): string {
  return dayKeyFormatter.format(date)
}

function enumerateDays(startDate: string, endDate: string): string[] {
  const days: string[] = []
  const start = parseDayBoundary(startDate, false)
  const end = parseDayBoundary(endDate, true)
  const cursor = new Date(start)
  cursor.setHours(0, 0, 0, 0)
  const endDay = new Date(end)
  endDay.setHours(0, 0, 0, 0)

  while (cursor <= endDay) {
    days.push(dayKey(cursor))
    cursor.setDate(cursor.getDate() + 1)
  }
  return days
}

function parseDayBoundary(value: string, endOfDay: boolean): Date {
  if (value.includes("T")) {
    return parseInstant(value)
  }
  const [year, month, day] = value.split("-").map(Number)
  const date = new Date(year, month - 1, day)
  if (endOfDay) {
    date.setHours(23, 59, 59, 999)
  } else {
    date.setHours(0, 0, 0, 0)
  }
  return date
}

function timedBusyMinutes(event: BridgeEvent, day: string): number {
  if (event.isAllDay) {
    return 0
  }
  const start = parseInstant(event.startDate)
  const end = parseInstant(event.endDate)
  const dayStart = parseDayBoundary(day, false)
  const dayEnd = parseDayBoundary(day, true)
  const overlapStart = Math.max(start.getTime(), dayStart.getTime())
  const overlapEnd = Math.min(end.getTime(), dayEnd.getTime())
  if (overlapEnd <= overlapStart) {
    return 0
  }
  return Math.round((overlapEnd - overlapStart) / 60_000)
}

function overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart < bEnd && bStart < aEnd
}

export function analyzeSchedule(
  events: BridgeEvent[],
  startDate: string,
  endDate: string,
  truncated: boolean,
  workMinutesPerDay = 8 * 60,
): ScheduleAnalysis {
  const days = enumerateDays(startDate, endDate)
  const dayStats = new Map<string, DayScheduleStats>()
  for (const date of days) {
    dayStats.set(date, {
      date,
      timedEventCount: 0,
      allDayEventCount: 0,
      meetingWithJoinUrlCount: 0,
      busyMinutes: 0,
      workMinutes: workMinutesPerDay,
      busyPercent: 0,
    })
  }

  const calendarStats = new Map<
    string,
    { calendarIdentifier: string; calendarTitle: string; eventCount: number; busyMinutes: number }
  >()

  let timedEventCount = 0
  let allDayEventCount = 0
  let meetingWithJoinUrlCount = 0
  let totalBusyMinutes = 0

  for (const event of events) {
    if (event.isAllDay) {
      allDayEventCount += 1
    } else {
      timedEventCount += 1
    }
    if (event.joinURL) {
      meetingWithJoinUrlCount += 1
    }

    const calendarKey = event.calendarIdentifier
    const existing = calendarStats.get(calendarKey) ?? {
      calendarIdentifier: event.calendarIdentifier,
      calendarTitle: event.calendarTitle,
      eventCount: 0,
      busyMinutes: 0,
    }
    existing.eventCount += 1

    for (const date of days) {
      const stats = dayStats.get(date)
      if (!stats) continue

      const eventStart = parseInstant(event.startDate)
      const eventEnd = parseInstant(event.endDate)
      const dayStart = parseDayBoundary(date, false)
      const dayEnd = parseDayBoundary(date, true)
      if (!overlaps(eventStart, eventEnd, dayStart, dayEnd)) {
        continue
      }

      if (event.isAllDay) {
        stats.allDayEventCount += 1
      } else {
        stats.timedEventCount += 1
        const minutes = timedBusyMinutes(event, date)
        stats.busyMinutes += minutes
        totalBusyMinutes += minutes
        existing.busyMinutes += minutes
        if (event.joinURL) {
          stats.meetingWithJoinUrlCount += 1
        }
      }
    }

    calendarStats.set(calendarKey, existing)
  }

  for (const stats of dayStats.values()) {
    stats.busyPercent =
      stats.workMinutes > 0 ? Math.round((stats.busyMinutes / stats.workMinutes) * 1000) / 10 : 0
  }

  return {
    startDate,
    endDate,
    totalEvents: events.length,
    truncated,
    timedEventCount,
    allDayEventCount,
    meetingWithJoinUrlCount,
    totalBusyMinutes,
    days: [...dayStats.values()],
    byCalendar: [...calendarStats.values()].sort((a, b) => b.busyMinutes - a.busyMinutes),
  }
}

export function findConflicts(events: BridgeEvent[]): ConflictGroup[] {
  const timed = events
    .filter((event) => !event.isAllDay)
    .map((event) => ({
      event,
      start: parseInstant(event.startDate),
      end: parseInstant(event.endDate),
    }))
    .sort((a, b) => a.start.getTime() - b.start.getTime())

  const groups: ConflictGroup[] = []
  let current: typeof timed = []

  for (const item of timed) {
    if (current.length === 0) {
      current = [item]
      continue
    }
    const groupEnd = Math.max(...current.map((entry) => entry.end.getTime()))
    if (item.start.getTime() < groupEnd) {
      current.push(item)
      continue
    }
    if (current.length > 1) {
      groups.push(conflictGroupFromEntries(current))
    }
    current = [item]
  }
  if (current.length > 1) {
    groups.push(conflictGroupFromEntries(current))
  }

  return groups
}

function conflictGroupFromEntries(
  entries: Array<{ event: BridgeEvent; start: Date; end: Date }>,
): ConflictGroup {
  const start = Math.min(...entries.map((entry) => entry.start.getTime()))
  const end = Math.max(...entries.map((entry) => entry.end.getTime()))
  return {
    start: new Date(start).toISOString(),
    end: new Date(end).toISOString(),
    events: entries.map((entry) => entry.event),
  }
}

function parseWorkTime(value: string, fallbackHour: number, fallbackMinute: number): number {
  const match = /^(\d{2}):(\d{2})$/.exec(value)
  if (!match) {
    return fallbackHour * 60 + fallbackMinute
  }
  return Number(match[1]) * 60 + Number(match[2])
}

export function findFreeTime(
  events: BridgeEvent[],
  startDate: string,
  endDate: string,
  workStart = "09:00",
  workEnd = "18:00",
  minDurationMinutes = 30,
): FreeTimeSlot[] {
  const days = enumerateDays(startDate, endDate)
  const workStartMinutes = parseWorkTime(workStart, 9, 0)
  const workEndMinutes = parseWorkTime(workEnd, 18, 0)
  const slots: FreeTimeSlot[] = []

  for (const date of days) {
    const busy: BusyInterval[] = events
      .filter((event) => !event.isAllDay)
      .map((event) => ({
        start: parseInstant(event.startDate),
        end: parseInstant(event.endDate),
        event,
      }))
      .filter((interval) => {
        const dayStart = parseDayBoundary(date, false)
        const dayEnd = parseDayBoundary(date, true)
        return overlaps(interval.start, interval.end, dayStart, dayEnd)
      })
      .map((interval) => {
        const dayStart = parseDayBoundary(date, false)
        const dayEnd = parseDayBoundary(date, true)
        return {
          start: new Date(Math.max(interval.start.getTime(), dayStart.getTime())),
          end: new Date(Math.min(interval.end.getTime(), dayEnd.getTime())),
          event: interval.event,
        }
      })
      .sort((a, b) => a.start.getTime() - b.start.getTime())

    const workStartDate = parseDayBoundary(date, false)
    workStartDate.setHours(Math.floor(workStartMinutes / 60), workStartMinutes % 60, 0, 0)
    const workEndDate = parseDayBoundary(date, false)
    workEndDate.setHours(Math.floor(workEndMinutes / 60), workEndMinutes % 60, 0, 0)

    let cursor = workStartDate
    for (const interval of busy) {
      if (interval.start > cursor) {
        pushSlotIfLongEnough(slots, cursor, interval.start, minDurationMinutes)
      }
      if (interval.end > cursor) {
        cursor = interval.end
      }
    }
    if (cursor < workEndDate) {
      pushSlotIfLongEnough(slots, cursor, workEndDate, minDurationMinutes)
    }
  }

  return slots
}

function pushSlotIfLongEnough(
  slots: FreeTimeSlot[],
  start: Date,
  end: Date,
  minDurationMinutes: number,
) {
  const durationMinutes = Math.round((end.getTime() - start.getTime()) / 60_000)
  if (durationMinutes >= minDurationMinutes) {
    slots.push({
      start: start.toISOString(),
      end: end.toISOString(),
      durationMinutes,
    })
  }
}
