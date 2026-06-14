import { mkdtemp, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { describe, expect, it } from "vitest"

import {
  attachPlaudRecordingsToEvents,
  dateToAppleSeconds,
  getPlaudStatus,
  listPlaudRecordings,
} from "../src/plaud.js"

const fileID = "99733db3d50cddf66f626e7b63495e49"

describe("Plaud cache reader", () => {
  it("lists recordings for a day and includes cached event matches", async () => {
    const directory = await mkdtemp(join(tmpdir(), "equinox-plaud-"))
    await writePlaudCatalog(directory, {
      recordings: [
        recording({
          fileID,
          title: "06-01 Обсуждение внедрения LLM",
          recordedAt: "2026-06-01T08:01:47.000Z",
          durationSeconds: 2009,
        }),
        recording({
          fileID: "08b11808ce5b448bcf4c8bed5e26098a",
          title: "06-04 Планирование",
          recordedAt: "2026-06-04T09:00:00.000Z",
          durationSeconds: 3600,
        }),
      ],
    })
    await writePlaudMatchCache(directory, {
      [`event-1|${Date.parse("2026-06-01T08:00:00.000Z") / 1000}`]: {
        fileID,
        webURLString: `https://web.plaud.ai/file/${fileID}`,
        source: "auto",
        matchedAt: dateToAppleSeconds(new Date("2026-06-14T13:00:00.000Z")),
      },
    })

    const data = await listPlaudRecordings({ date: "2026-06-01" }, directory)

    expect(data.catalog.available).toBe(true)
    expect(data.count).toBe(1)
    expect(data.recordings[0]).toMatchObject({
      fileID,
      title: "06-01 Обсуждение внедрения LLM",
      recordedAt: "2026-06-01T08:01:47.000Z",
      endDate: "2026-06-01T08:35:16.000Z",
      durationSeconds: 2009,
      webURL: `https://web.plaud.ai/file/${fileID}`,
    })
    expect(data.recordings[0].matchedEvents).toEqual([
      {
        eventIdentifier: "event-1",
        eventStartDate: "2026-06-01T08:00:00.000Z",
        fileID,
        webURL: `https://web.plaud.ai/file/${fileID}`,
        source: "auto",
        matchedAt: "2026-06-14T13:00:00.000Z",
      },
    ])
  })

  it("attaches cached Plaud matches to calendar events", async () => {
    const directory = await mkdtemp(join(tmpdir(), "equinox-plaud-"))
    await writePlaudCatalog(directory, {
      recordings: [
        recording({
          fileID,
          title: "06-01 Обсуждение внедрения LLM",
          recordedAt: "2026-06-01T08:01:47.000Z",
          durationSeconds: 2009,
        }),
      ],
    })
    await writePlaudMatchCache(directory, {
      [`event-1|${Date.parse("2026-06-01T08:00:00.000Z") / 1000}`]: {
        fileID,
        webURLString: `https://web.plaud.ai/file/${fileID}`,
        source: "auto",
        matchedAt: dateToAppleSeconds(new Date("2026-06-14T13:00:00.000Z")),
      },
    })

    const events = await attachPlaudRecordingsToEvents(
      [
        {
          eventIdentifier: "event-1",
          startDate: "2026-06-01T08:00:00.000Z",
          title: "SocServ | QA Captains Weekly",
        },
        {
          eventIdentifier: "event-2",
          startDate: "2026-06-01T10:00:00.000Z",
          title: "QA Обед",
        },
      ],
      directory,
    )

    expect(events[0]).toMatchObject({
      title: "SocServ | QA Captains Weekly",
      hasPlaudRecording: true,
      plaudRecording: {
        fileID,
        title: "06-01 Обсуждение внедрения LLM",
        recordedAt: "2026-06-01T08:01:47.000Z",
        endDate: "2026-06-01T08:35:16.000Z",
        durationSeconds: 2009,
        webURL: `https://web.plaud.ai/file/${fileID}`,
        source: "auto",
        matchedAt: "2026-06-14T13:00:00.000Z",
      },
    })
    expect(events[1]).toMatchObject({
      title: "QA Обед",
      hasPlaudRecording: false,
      plaudRecording: null,
    })
  })

  it("reports unsupported catalog schemas as unavailable", async () => {
    const directory = await mkdtemp(join(tmpdir(), "equinox-plaud-"))
    await writePlaudCatalog(directory, {
      schemaVersion: 1,
      recordings: [
        recording({
          fileID,
          title: "old",
          recordedAt: "2026-06-01T08:01:47.000Z",
          durationSeconds: 1,
        }),
      ],
    })

    const data = await listPlaudRecordings({ date: "2026-06-01" }, directory)

    expect(data.catalog.available).toBe(false)
    expect(data.catalog.reason).toBe("unsupported_schema_version")
    expect(data.count).toBe(0)
  })

  it("returns status when cache files are missing", async () => {
    const directory = await mkdtemp(join(tmpdir(), "equinox-plaud-"))

    const status = await getPlaudStatus(directory)

    expect(status.catalog).toMatchObject({
      available: false,
      recordCount: 0,
      reason: "catalog_missing",
    })
    expect(status.matchCache).toMatchObject({
      available: false,
      positiveMatchCount: 0,
      negativeMatchCount: 0,
      reason: "match_cache_missing",
    })
  })
})

function recording(input: {
  fileID: string
  title: string
  recordedAt: string
  durationSeconds: number
}) {
  return {
    fileID: input.fileID,
    title: input.title,
    recordedAt: dateToAppleSeconds(new Date(input.recordedAt)),
    durationSeconds: input.durationSeconds,
  }
}

async function writePlaudCatalog(
  directory: string,
  input: {
    schemaVersion?: number
    recordings: unknown[]
  },
) {
  await writeFile(
    join(directory, "plaud-recordings.json"),
    JSON.stringify({
      schemaVersion: input.schemaVersion ?? 2,
      fetchedAt: dateToAppleSeconds(new Date("2026-06-14T13:00:00.000Z")),
      fingerprint: "fingerprint",
      recordings: input.recordings,
    }),
  )
}

async function writePlaudMatchCache(directory: string, matches: Record<string, unknown>) {
  await writeFile(
    join(directory, "plaud-match-cache.json"),
    JSON.stringify({
      v: 1,
      indexFingerprint: "fingerprint",
      matches,
      negatives: {
        "event-2|1780304400.0": {
          checkedAt: dateToAppleSeconds(new Date("2026-06-14T13:00:00.000Z")),
          indexFingerprint: "fingerprint",
        },
      },
    }),
  )
}
