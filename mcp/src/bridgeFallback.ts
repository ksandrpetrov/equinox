const mutatingCommands = new Set(["create_event", "update_event", "delete_event"])

/** HTTP statuses where the app bridge rejected the request before launching equinox-bridge. */
const preBridgeRejectionStatuses = new Set([401, 404, 413])

export type AppBridgeFailureKind =
  | "state_missing"
  | "connection_refused"
  | "timeout"
  | "http_error"
  | "empty_body"
  | "invalid_json"
  | "invocation_failed"

export function isMutatingBridgeCommand(command: Record<string, unknown>): boolean {
  return typeof command.command === "string" && mutatingCommands.has(command.command)
}

export function shouldFallbackToCli(
  failure: AppBridgeFailureKind,
  isMutating: boolean,
  httpStatus?: number,
): boolean {
  if (failure === "state_missing" || failure === "connection_refused") {
    return true
  }
  if (httpStatus !== undefined && preBridgeRejectionStatuses.has(httpStatus)) {
    return true
  }
  if (isMutating) {
    return false
  }
  return failure === "http_error" || failure === "empty_body" || failure === "invalid_json"
    || failure === "invocation_failed" || failure === "timeout"
}

export function classifyNodeError(error: unknown): AppBridgeFailureKind {
  if (!(error instanceof Error)) {
    return "invocation_failed"
  }
  const code = (error as NodeJS.ErrnoException).code
  if (code === "ECONNREFUSED" || code === "ENOTFOUND") {
    return "connection_refused"
  }
  if (error.message.includes("timed out")) {
    return "timeout"
  }
  return "invocation_failed"
}
