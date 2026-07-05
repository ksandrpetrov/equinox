import { bridgeUpdateMutableFields as generatedMutableFields } from "./schemas/generated/bridgeEventKeys.js"

export { bridgeUpdateMutableFields } from "./schemas/generated/bridgeEventKeys.js"

export function updateHasMutableField(input: Record<string, unknown>): boolean {
  return generatedMutableFields.some((key) => input[key] !== undefined)
}
