const UPDATE_MUTABLE_FIELDS = [
  "title",
  "startDate",
  "endDate",
  "allDay",
  "location",
  "notes",
  "url",
  "calendarId",
] as const

export function assertEndAfterStart(startDate: string, endDate: string, endLabel = "endDate"): void {
  const startMs = Date.parse(startDate)
  const endMs = Date.parse(endDate)
  if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || endMs <= startMs) {
    throw new Error(`${endLabel} must be after startDate`)
  }
}

export function assertUpdateHasMutableField(input: Record<string, unknown>): void {
  const hasField = UPDATE_MUTABLE_FIELDS.some((key) => input[key] !== undefined)
  if (!hasField) {
    throw new Error("update_event requires at least one mutable field")
  }
}

export const bridgeUpdateMutableFields = UPDATE_MUTABLE_FIELDS
