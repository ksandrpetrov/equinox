import { BridgeInvocationError, BridgeNotFoundError } from "./bridge.js"
import { PlaudCacheError } from "./plaud.js"

type ToolErrorPayload = {
  code: string
  message: string
  hint: string
}

export function toolErrorResult(error: unknown) {
  const payload = describeToolError(error)
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(payload, null, 2),
      },
    ],
    structuredContent: payload,
    isError: true as const,
  }
}

export async function runToolSafely<T>(operation: () => Promise<T>) {
  try {
    return await operation()
  } catch (error) {
    return toolErrorResult(error)
  }
}

function describeToolError(error: unknown): ToolErrorPayload {
  if (error instanceof BridgeNotFoundError) {
    return {
      code: "bridge_not_found",
      message: error.message,
      hint: "Соберите bridge: ./scripts/build-mcp.sh",
    }
  }
  if (error instanceof BridgeInvocationError) {
    return bridgeInvocationHint(error.message)
  }
  if (error instanceof PlaudCacheError) {
    return {
      code: "plaud_cache_error",
      message: error.message,
      hint: "Plaud-инструменты читают только локальный кэш Equinox; откройте настройки Plaud в equinox.app.",
    }
  }
  if (error instanceof Error) {
    if (error.message.startsWith("access_denied:")) {
      return {
        code: "access_denied",
        message: error.message,
        hint: "Запустите equinox.app или вызовите request_calendar_access.",
      }
    }
    if (error.message.includes("Date range spans")) {
      return {
        code: "invalid_request",
        message: error.message,
        hint: "Сузьте диапазон дат до 366 дней или меньше.",
      }
    }
    return {
      code: "tool_error",
      message: error.message,
      hint: "Проверьте входные параметры и доступ к календарю.",
    }
  }
  return {
    code: "unknown_error",
    message: String(error),
    hint: "Повторите запрос или проверьте логи equinox-mcp.",
  }
}

function bridgeInvocationHint(message: string): ToolErrorPayload {
  if (message.includes("timed out") && message.includes("mutation")) {
    return {
      code: "mutation_timeout",
      message,
      hint: "Проверьте результат через list_events/get_event перед повторной мутацией.",
    }
  }
  if (message.includes("timed out")) {
    return {
      code: "bridge_timeout",
      message,
      hint: "Увеличьте EQUINOX_APP_BRIDGE_TIMEOUT_MS или запустите equinox.app.",
    }
  }
  if (message.includes("bridge_invalid_response")) {
    return {
      code: "bridge_invalid_response",
      message,
      hint: "Обновите equinox.app и equinox-bridge до одной версии.",
    }
  }
  return {
    code: "bridge_invocation_failed",
    message,
    hint: "Запустите equinox.app для app-bridge или ./scripts/build-mcp.sh для CLI fallback.",
  }
}
