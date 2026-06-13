export type BridgeError = {
  code: string
  message: string
}

export type BridgeResponse<T = unknown> = {
  ok: boolean
  data?: T
  error?: BridgeError
}

export type BridgeCalendar = {
  id: string
  title: string
  sourceTitle: string
  sourceIdentifier: string
  colorHex: string
  allowsContentModifications: boolean
  isSubscribed: boolean
  type: string
}

export type BridgeEvent = {
  eventIdentifier: string | null
  calendarItemIdentifier: string
  title: string
  location: string | null
  notes: string | null
  url: string | null
  startDate: string
  endDate: string
  isAllDay: boolean
  joinURL: string | null
  calendarIdentifier: string
  calendarTitle: string
  calendarColorHex: string
  allowsContentModifications: boolean
  hasAttendees: boolean
}

export type AccessStatusData = {
  status: string
  granted: boolean
}

export type AccessRequestData = {
  granted: boolean
  status: string
}

export type CalendarsData = {
  calendars: BridgeCalendar[]
}

export type EventsData = {
  events: BridgeEvent[]
  truncated: boolean
}

export type EventData = {
  event: BridgeEvent
}

export type MutationData = {
  eventIdentifier: string | null
  calendarItemIdentifier: string | null
}
