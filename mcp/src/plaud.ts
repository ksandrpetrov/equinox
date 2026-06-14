import { existsSync } from "node:fs"
import { readFile } from "node:fs/promises"
import { homedir } from "node:os"
import { resolve } from "node:path"

const appleReferenceUnixSeconds = 978_307_200
const currentPlaudRecordingsSchemaVersion = 2
const plaudWebBaseURL = "https://web.plaud.ai/file/"
const defaultLimit = 100

type JsonRecord = Record<string, unknown>

type PlaudCatalogStatus = {
  available: boolean
  recordCount: number
  expectedSchemaVersion: number
  schemaVersion?: number
  fetchedAt?: string
  fingerprint?: string
  reason?: string
}

type PlaudMatchCacheStatus = {
  available: boolean
  positiveMatchCount: number
  negativeMatchCount: number
  fingerprint?: string
  reason?: string
}

type PlaudRecording = {
  fileID: string
  title: string
  recordedAt: Date
  durationSeconds: number
}

type PlaudEventMatch = {
  eventIdentifier: string
  eventStartDate: string
  fileID: string
  webURL: string
  source: string
  matchedAt?: string
}

type PlaudMatchCache = {
  status: PlaudMatchCacheStatus
  matchesByFileID: Map<string, PlaudEventMatch[]>
  matchesByEventKey: Map<string, PlaudEventMatch>
}

type PlaudSnapshot = {
  status: PlaudCatalogStatus
  recordings: PlaudRecording[]
}

export type PlaudRecordingsInput = {
  date?: string
  startDate?: string
  endDate?: string
  limit?: number
}

export type PlaudStatusData = {
  catalog: PlaudCatalogStatus
  matchCache: PlaudMatchCacheStatus
}

export type PlaudRecordingData = {
  fileID: string
  title: string
  recordedAt: string
  endDate: string
  durationSeconds: number
  webURL: string
  matchedEvents: PlaudEventMatch[]
}

export type PlaudEventRecordingData = {
  fileID: string
  webURL: string
  source: string
  matchedAt?: string
  title?: string
  recordedAt?: string
  endDate?: string
  durationSeconds?: number
}

export type PlaudRecordingsData = PlaudStatusData & {
  startDate: string
  endDate: string
  count: number
  totalMatching: number
  truncated: boolean
  recordings: PlaudRecordingData[]
}

type MatchableCalendarEvent = {
  eventIdentifier?: string | null
  startDate: string
}

export type PlaudAugmentedEvent<T extends MatchableCalendarEvent> = T & {
  hasPlaudRecording: boolean
  plaudRecording: PlaudEventRecordingData | null
}

export class PlaudCacheError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "PlaudCacheError"
  }
}

export function defaultPlaudCacheDirectory(): string {
  return process.env.EQUINOX_PLAUD_CACHE_DIR
    ?? resolve(homedir(), "Library/Application Support/com.equinox.equinoxApp")
}

export async function getPlaudStatus(
  cacheDirectory = defaultPlaudCacheDirectory(),
): Promise<PlaudStatusData> {
  const [snapshot, matchCache] = await Promise.all([
    loadPlaudSnapshot(cacheDirectory),
    loadPlaudMatchCache(cacheDirectory),
  ])
  return {
    catalog: snapshot.status,
    matchCache: matchCache.status,
  }
}

export async function listPlaudRecordings(
  input: PlaudRecordingsInput,
  cacheDirectory = defaultPlaudCacheDirectory(),
): Promise<PlaudRecordingsData> {
  const range = resolveRecordingRange(input)
  const limit = input.limit ?? defaultLimit
  const [snapshot, matchCache] = await Promise.all([
    loadPlaudSnapshot(cacheDirectory),
    loadPlaudMatchCache(cacheDirectory),
  ])

  const matching = snapshot.recordings
    .filter((recording) => recording.recordedAt >= range.start && recording.recordedAt < range.end)
    .sort((a, b) => a.recordedAt.getTime() - b.recordedAt.getTime())
  const selected = matching.slice(0, limit)

  return {
    catalog: snapshot.status,
    matchCache: matchCache.status,
    startDate: range.start.toISOString(),
    endDate: range.end.toISOString(),
    count: selected.length,
    totalMatching: matching.length,
    truncated: matching.length > selected.length,
    recordings: selected.map((recording) => serializeRecording(recording, matchCache)),
  }
}

export async function attachPlaudRecordingsToEvents<T extends MatchableCalendarEvent>(
  events: T[],
  cacheDirectory = defaultPlaudCacheDirectory(),
): Promise<PlaudAugmentedEvent<T>[]> {
  const [snapshot, matchCache] = await Promise.all([
    loadPlaudSnapshot(cacheDirectory),
    loadPlaudMatchCache(cacheDirectory),
  ])
  const recordingsByFileID = new Map(snapshot.recordings.map((recording) => [recording.fileID, recording]))

  return events.map((event) => {
    const match = plaudMatchForEvent(event, matchCache)
    if (!match) {
      return {
        ...event,
        hasPlaudRecording: false,
        plaudRecording: null,
      }
    }

    return {
      ...event,
      hasPlaudRecording: true,
      plaudRecording: serializeEventRecording(match, recordingsByFileID.get(match.fileID)),
    }
  })
}

export function appleSecondsToDate(value: unknown): Date | undefined {
  if (!isFiniteNumber(value)) {
    return undefined
  }
  return new Date((value + appleReferenceUnixSeconds) * 1000)
}

export function dateToAppleSeconds(date: Date): number {
  return date.getTime() / 1000 - appleReferenceUnixSeconds
}

async function loadPlaudSnapshot(cacheDirectory: string): Promise<PlaudSnapshot> {
  const filePath = resolve(cacheDirectory, "plaud-recordings.json")
  if (!existsSync(filePath)) {
    return {
      status: catalogStatus(false, 0, "catalog_missing"),
      recordings: [],
    }
  }

  const raw = await readJsonRecord(filePath)
  if (!raw) {
    return {
      status: catalogStatus(false, 0, "catalog_invalid"),
      recordings: [],
    }
  }

  const schemaVersion = isFiniteNumber(raw.schemaVersion) ? raw.schemaVersion : 1
  const rawRecordings = Array.isArray(raw.recordings) ? raw.recordings : []
  const fetchedAt = appleSecondsToDate(raw.fetchedAt)?.toISOString()
  const fingerprint = typeof raw.fingerprint === "string" ? raw.fingerprint : undefined
  if (schemaVersion !== currentPlaudRecordingsSchemaVersion) {
    return {
      status: catalogStatus(false, 0, "unsupported_schema_version", {
        schemaVersion,
        fetchedAt,
        fingerprint,
      }),
      recordings: [],
    }
  }

  const recordings = rawRecordings
    .map(parseRecording)
    .filter((recording): recording is PlaudRecording => recording !== undefined)

  return {
    status: catalogStatus(true, recordings.length, undefined, {
      schemaVersion,
      fetchedAt,
      fingerprint,
    }),
    recordings,
  }
}

async function loadPlaudMatchCache(cacheDirectory: string): Promise<PlaudMatchCache> {
  const filePath = resolve(cacheDirectory, "plaud-match-cache.json")
  if (!existsSync(filePath)) {
    return emptyMatchCache("match_cache_missing")
  }

  const raw = await readJsonRecord(filePath)
  if (!raw) {
    return emptyMatchCache("match_cache_invalid")
  }

  const rawMatches = isRecord(raw.matches) ? raw.matches : {}
  const rawNegatives = isRecord(raw.negatives) ? raw.negatives : {}
  const matchesByFileID = new Map<string, PlaudEventMatch[]>()
  const matchesByEventKey = new Map<string, PlaudEventMatch>()
  for (const [key, value] of Object.entries(rawMatches)) {
    const match = parseMatch(key, value)
    if (!match) {
      continue
    }
    const existing = matchesByFileID.get(match.fileID) ?? []
    existing.push(match)
    matchesByFileID.set(match.fileID, existing)
    matchesByEventKey.set(eventLookupKey(match.eventIdentifier, match.eventStartDate), match)
  }

  for (const matches of matchesByFileID.values()) {
    matches.sort((a, b) => a.eventStartDate.localeCompare(b.eventStartDate))
  }

  return {
    status: {
      available: true,
      positiveMatchCount: Object.keys(rawMatches).length,
      negativeMatchCount: Object.keys(rawNegatives).length,
      fingerprint: typeof raw.indexFingerprint === "string" ? raw.indexFingerprint : undefined,
    },
    matchesByFileID,
    matchesByEventKey,
  }
}

async function readJsonRecord(filePath: string): Promise<JsonRecord | undefined> {
  try {
    const raw = await readFile(filePath, "utf8")
    const parsed = JSON.parse(raw) as unknown
    return isRecord(parsed) ? parsed : undefined
  } catch {
    return undefined
  }
}

function parseRecording(value: unknown): PlaudRecording | undefined {
  if (!isRecord(value)) {
    return undefined
  }
  const fileID = normalizeFileID(value.fileID)
  const recordedAt = appleSecondsToDate(value.recordedAt)
  if (!fileID || !recordedAt) {
    return undefined
  }
  return {
    fileID,
    title: typeof value.title === "string" && value.title.length > 0 ? value.title : fileID,
    recordedAt,
    durationSeconds: isFiniteNumber(value.durationSeconds) ? Math.max(0, value.durationSeconds) : 0,
  }
}

function parseMatch(key: string, value: unknown): PlaudEventMatch | undefined {
  if (!isRecord(value)) {
    return undefined
  }
  const fileID = normalizeFileID(value.fileID)
  if (!fileID) {
    return undefined
  }
  const separator = key.lastIndexOf("|")
  if (separator <= 0 || separator >= key.length - 1) {
    return undefined
  }
  const eventIdentifier = key.slice(0, separator)
  const eventStartSeconds = Number(key.slice(separator + 1))
  if (!Number.isFinite(eventStartSeconds)) {
    return undefined
  }
  const webURL = typeof value.webURLString === "string"
    ? value.webURLString
    : plaudWebURL(fileID)
  return {
    eventIdentifier,
    eventStartDate: new Date(eventStartSeconds * 1000).toISOString(),
    fileID,
    webURL,
    source: typeof value.source === "string" ? value.source : "auto",
    matchedAt: appleSecondsToDate(value.matchedAt)?.toISOString(),
  }
}

function serializeRecording(
  recording: PlaudRecording,
  matchCache: PlaudMatchCache,
): PlaudRecordingData {
  const durationSeconds = Math.max(0, recording.durationSeconds)
  const endDate = new Date(recording.recordedAt.getTime() + durationSeconds * 1000)
  return {
    fileID: recording.fileID,
    title: recording.title,
    recordedAt: recording.recordedAt.toISOString(),
    endDate: endDate.toISOString(),
    durationSeconds,
    webURL: plaudWebURL(recording.fileID),
    matchedEvents: matchCache.matchesByFileID.get(recording.fileID) ?? [],
  }
}

function serializeEventRecording(
  match: PlaudEventMatch,
  recording: PlaudRecording | undefined,
): PlaudEventRecordingData {
  if (!recording) {
    return {
      fileID: match.fileID,
      webURL: match.webURL,
      source: match.source,
      matchedAt: match.matchedAt,
    }
  }

  const durationSeconds = Math.max(0, recording.durationSeconds)
  const endDate = new Date(recording.recordedAt.getTime() + durationSeconds * 1000)
  return {
    fileID: match.fileID,
    title: recording.title,
    recordedAt: recording.recordedAt.toISOString(),
    endDate: endDate.toISOString(),
    durationSeconds,
    webURL: match.webURL,
    source: match.source,
    matchedAt: match.matchedAt,
  }
}

function plaudMatchForEvent(
  event: MatchableCalendarEvent,
  matchCache: PlaudMatchCache,
): PlaudEventMatch | undefined {
  if (!event.eventIdentifier) {
    return undefined
  }
  const startDate = new Date(event.startDate)
  if (!Number.isFinite(startDate.getTime())) {
    return undefined
  }
  return matchCache.matchesByEventKey.get(eventLookupKey(event.eventIdentifier, startDate.toISOString()))
}

function eventLookupKey(eventIdentifier: string, eventStartDate: string): string {
  return `${eventIdentifier}|${eventStartDate}`
}

function resolveRecordingRange(input: PlaudRecordingsInput): { start: Date; end: Date } {
  const startDate = input.date ?? input.startDate
  if (!startDate) {
    throw new PlaudCacheError("Provide either date or startDate.")
  }
  const start = parseLocalDate(startDate)
  const end = input.date || !input.endDate
    ? addLocalDays(start, 1)
    : parseLocalDate(input.endDate)
  if (end <= start) {
    throw new PlaudCacheError("endDate must be after startDate.")
  }
  return { start, end }
}

function parseLocalDate(value: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (!match) {
    throw new PlaudCacheError(`Invalid date: ${value}`)
  }
  const year = Number(match[1])
  const month = Number(match[2])
  const day = Number(match[3])
  const date = new Date(year, month - 1, day, 0, 0, 0, 0)
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    throw new PlaudCacheError(`Invalid date: ${value}`)
  }
  return date
}

function addLocalDays(date: Date, days: number): Date {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate() + days,
    date.getHours(),
    date.getMinutes(),
    date.getSeconds(),
    date.getMilliseconds(),
  )
}

function catalogStatus(
  available: boolean,
  recordCount: number,
  reason?: string,
  extra: Partial<PlaudCatalogStatus> = {},
): PlaudCatalogStatus {
  return {
    available,
    recordCount,
    expectedSchemaVersion: currentPlaudRecordingsSchemaVersion,
    reason,
    ...extra,
  }
}

function emptyMatchCache(reason: string): PlaudMatchCache {
  return {
    status: {
      available: false,
      positiveMatchCount: 0,
      negativeMatchCount: 0,
      reason,
    },
    matchesByFileID: new Map(),
    matchesByEventKey: new Map(),
  }
}

function plaudWebURL(fileID: string): string {
  return plaudWebBaseURL + fileID
}

function normalizeFileID(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined
  }
  const normalized = value.toLowerCase().replaceAll("-", "")
  return /^[0-9a-f]{32}$/.test(normalized) ? normalized : undefined
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value)
}
