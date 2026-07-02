import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { assertAnalyticsDateRange } from "../analytics/schedule.js"
import { analyzeSchedule, findConflicts, findFreeTime } from "../analytics/schedule.js"
import { invokeBridge, requireBridgeData } from "../bridge.js"
import { attachPlaudRecordingsToEvents } from "../plaud.js"
import {
  eventOutputSchema,
  eventsDataSchema,
  findConflictsOutputSchema,
  findFreeTimeOutputSchema,
  getEventBridgeDataSchema,
  mutationOutputSchema,
  scheduleAnalysisOutputSchema,
} from "../schemas/outputs.js"
import {
  analyzeScheduleInputSchema,
  createEventInputSchema,
  deleteEventInputSchema,
  findConflictsInputSchema,
  findFreeTimeInputSchema,
  getEventInputSchema,
  listEventsInputSchema,
  updateEventInputSchema,
} from "../schemas/toolInputs.js"
import { jsonToolResult } from "../toolResponse.js"
import { runToolSafely } from "../toolErrors.js"
import type { EventData, EventsData } from "../types.js"

const listEventsDescription =
  "Возвращает события за диапазон дат (YYYY-MM-DD, endDate включительно, локальная таймзона машины). "
  + "Опционально фильтрует по calendarIds. Лимит до 500 событий; truncated=true означает, что событий больше. "
  + "По умолчанию добавляет hasPlaudRecording/plaudRecording из локального Plaud-кэша (includePlaud=false отключает)."

export function registerEventTools(server: McpServer) {
  server.registerTool(
    "list_events",
    {
      title: "Список событий",
      description: listEventsDescription,
      inputSchema: listEventsInputSchema,
      outputSchema: eventsDataSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      const { includePlaud, ...bridgeInput } = input
      const response = await invokeBridge<EventsData>({
        command: "list_events",
        ...bridgeInput,
      })
      const data = requireBridgeData(response, eventsDataSchema)
      if (includePlaud === false) {
        return jsonToolResult(data)
      }
      return jsonToolResult({
        ...data,
        events: await attachPlaudRecordingsToEvents(data.events),
      })
    }),
  )

  server.registerTool(
    "get_event",
    {
      title: "Получить событие",
      description:
        "Возвращает одно событие по eventIdentifier и всегда обогащает его данными Plaud-кэша, если привязка есть.",
      inputSchema: getEventInputSchema,
      outputSchema: eventOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async ({ eventIdentifier }) => runToolSafely(async () => {
      const response = await invokeBridge<EventData>({
        command: "get_event",
        eventIdentifier,
      })
      const data = requireBridgeData(response, getEventBridgeDataSchema)
      const [event] = await attachPlaudRecordingsToEvents([data.event])
      return jsonToolResult({ event })
    }),
  )

  server.registerTool(
    "create_event",
    {
      title: "Создать событие",
      description:
        "Создаёт событие в выбранном или дефолтном календаре. Даты — ISO-8601 или YYYY-MM-DD (локальная таймзона для date-only). "
        + "endDate должна быть позже startDate. url должен быть валидным URL.",
      inputSchema: createEventInputSchema,
      outputSchema: mutationOutputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      const response = await invokeBridge({
        command: "create_event",
        ...input,
      })
      return jsonToolResult(requireBridgeData(response, mutationOutputSchema))
    }),
  )

  server.registerTool(
    "update_event",
    {
      title: "Обновить событие",
      description:
        "Частично обновляет событие по eventIdentifier. Если переданы обе даты, endDate должна быть позже startDate.",
      inputSchema: updateEventInputSchema,
      outputSchema: mutationOutputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      const response = await invokeBridge({
        command: "update_event",
        ...input,
      })
      return jsonToolResult(requireBridgeData(response, mutationOutputSchema))
    }),
  )

  server.registerTool(
    "delete_event",
    {
      title: "Удалить событие",
      description:
        "Удаляет событие по eventIdentifier. span по умолчанию thisEvent; futureEvents удаляет будущие повторения серии.",
      inputSchema: deleteEventInputSchema,
      outputSchema: mutationOutputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async ({ eventIdentifier, span }) => runToolSafely(async () => {
      const response = await invokeBridge({
        command: "delete_event",
        eventIdentifier,
        span,
      })
      return jsonToolResult(requireBridgeData(response, mutationOutputSchema))
    }),
  )
}

export function registerAnalyticsTools(server: McpServer) {
  server.registerTool(
    "analyze_schedule",
    {
      title: "Анализ расписания",
      description:
        "Считает загрузку по дням и календарям: busy minutes, % занятости, встречи с join URL, all-day vs timed. "
        + "Диапазон дат включительный, максимум 366 дней, локальная таймзона для YYYY-MM-DD.",
      inputSchema: analyzeScheduleInputSchema,
      outputSchema: scheduleAnalysisOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      assertAnalyticsDateRange(input.startDate, input.endDate)
      const response = await invokeBridge<EventsData>({
        command: "list_events",
        startDate: input.startDate,
        endDate: input.endDate,
        calendarIds: input.calendarIds,
        limit: 500,
      })
      const data = requireBridgeData(response, eventsDataSchema)
      const analysis = analyzeSchedule(
        data.events,
        input.startDate,
        input.endDate,
        data.truncated,
        input.workMinutesPerDay,
      )
      return jsonToolResult(analysis)
    }),
  )

  server.registerTool(
    "find_conflicts",
    {
      title: "Найти конфликты",
      description:
        "Находит пересекающиеся timed-события в диапазоне дат (endDate включительно, максимум 366 дней).",
      inputSchema: findConflictsInputSchema,
      outputSchema: findConflictsOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      assertAnalyticsDateRange(input.startDate, input.endDate)
      const response = await invokeBridge<EventsData>({
        command: "list_events",
        ...input,
        limit: 500,
      })
      const data = requireBridgeData(response, eventsDataSchema)
      return jsonToolResult({
        startDate: input.startDate,
        endDate: input.endDate,
        truncated: data.truncated,
        conflictGroups: findConflicts(data.events),
      })
    }),
  )

  server.registerTool(
    "find_free_time",
    {
      title: "Найти свободное время",
      description:
        "Возвращает свободные слоты длительностью не меньше minDurationMinutes в рабочих часах (по умолчанию 09:00–18:00). "
        + "Диапазон дат включительный, максимум 366 дней.",
      inputSchema: findFreeTimeInputSchema,
      outputSchema: findFreeTimeOutputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => runToolSafely(async () => {
      assertAnalyticsDateRange(input.startDate, input.endDate)
      const response = await invokeBridge<EventsData>({
        command: "list_events",
        startDate: input.startDate,
        endDate: input.endDate,
        calendarIds: input.calendarIds,
        limit: 500,
      })
      const data = requireBridgeData(response, eventsDataSchema)
      const slots = findFreeTime(
        data.events,
        input.startDate,
        input.endDate,
        input.workStart,
        input.workEnd,
        input.minDurationMinutes,
      )
      return jsonToolResult({
        startDate: input.startDate,
        endDate: input.endDate,
        truncated: data.truncated,
        workStart: input.workStart ?? "09:00",
        workEnd: input.workEnd ?? "18:00",
        minDurationMinutes: input.minDurationMinutes ?? 30,
        slots,
      })
    }),
  )
}
