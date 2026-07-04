import { z } from "zod"

import { mcpEnrichedEventSchema } from "./events.js"

/** JSON Schema for equinox://schema/event — derived from runtime Zod validation. */
export const eventResourceSchema = {
  ...z.toJSONSchema(mcpEnrichedEventSchema),
  title: "EquinoxBridgeEvent",
} as const
