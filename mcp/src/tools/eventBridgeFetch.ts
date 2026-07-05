import { invokeBridge, requireBridgeData } from "../bridge.js"
import { bridgeEventsDataSchema } from "../schemas/events.js"
import type { EventsData } from "../types.js"

export async function fetchBridgeEventsForRange(
  input: { startDate: string; endDate: string; calendarIds?: string[] },
  limit = 500,
): Promise<EventsData> {
  const response = await invokeBridge<EventsData>({
    command: "list_events",
    startDate: input.startDate,
    endDate: input.endDate,
    calendarIds: input.calendarIds,
    limit,
  })
  return requireBridgeData(response, bridgeEventsDataSchema)
}
