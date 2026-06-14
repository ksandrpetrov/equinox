import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { analyzeSchedule, findConflicts, findFreeTime } from "../analytics/schedule.js"
import { invokeBridge, requireBridgeData } from "../bridge.js"
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
import type {
  EventData,
  EventsData,
  MutationData,
} from "../types.js"

export function registerEventTools(server: McpServer) {
  server.registerTool(
    "list_events",
    {
      title: "Список событий",
      description:
        "Возвращает события за диапазон дат (YYYY-MM-DD). Опционально фильтрует по calendarIds. Лимит до 500 событий.",
      inputSchema: listEventsInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<EventsData>({
        command: "list_events",
        ...input,
      })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "get_event",
    {
      title: "Получить событие",
      description: "Возвращает одно событие по eventIdentifier.",
      inputSchema: getEventInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async ({ eventIdentifier }) => {
      const response = invokeBridge<EventData>({
        command: "get_event",
        eventIdentifier,
      })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "create_event",
    {
      title: "Создать событие",
      description:
        "Создаёт событие в выбранном или дефолтном календаре. Даты — ISO-8601 или YYYY-MM-DD.",
      inputSchema: createEventInputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<MutationData>({
        command: "create_event",
        ...input,
      })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "update_event",
    {
      title: "Обновить событие",
      description: "Частично обновляет событие по eventIdentifier.",
      inputSchema: updateEventInputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<MutationData>({
        command: "update_event",
        ...input,
      })
      return jsonToolResult(requireBridgeData(response))
    },
  )

  server.registerTool(
    "delete_event",
    {
      title: "Удалить событие",
      description: "Удаляет событие по eventIdentifier. span: thisEvent или futureEvents.",
      inputSchema: deleteEventInputSchema,
      annotations: {
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async ({ eventIdentifier, span }) => {
      const response = invokeBridge<MutationData>({
        command: "delete_event",
        eventIdentifier,
        span,
      })
      return jsonToolResult(requireBridgeData(response))
    },
  )
}

export function registerAnalyticsTools(server: McpServer) {
  server.registerTool(
    "analyze_schedule",
    {
      title: "Анализ расписания",
      description:
        "Считает загрузку по дням и календарям: busy minutes, % занятости, встречи с join URL, all-day vs timed.",
      inputSchema: analyzeScheduleInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<EventsData>({
        command: "list_events",
        startDate: input.startDate,
        endDate: input.endDate,
        calendarIds: input.calendarIds,
      })
      const data = requireBridgeData(response)
      const analysis = analyzeSchedule(
        data.events,
        input.startDate,
        input.endDate,
        data.truncated,
        input.workMinutesPerDay,
      )
      return jsonToolResult(analysis)
    },
  )

  server.registerTool(
    "find_conflicts",
    {
      title: "Найти конфликты",
      description: "Находит пересекающиеся timed-события в диапазоне дат.",
      inputSchema: findConflictsInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<EventsData>({
        command: "list_events",
        ...input,
      })
      const data = requireBridgeData(response)
      return jsonToolResult({
        startDate: input.startDate,
        endDate: input.endDate,
        truncated: data.truncated,
        conflictGroups: findConflicts(data.events),
      })
    },
  )

  server.registerTool(
    "find_free_time",
    {
      title: "Найти свободное время",
      description:
        "Возвращает свободные слоты длительностью не меньше minDurationMinutes в рабочих часах.",
      inputSchema: findFreeTimeInputSchema,
      annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (input) => {
      const response = invokeBridge<EventsData>({
        command: "list_events",
        startDate: input.startDate,
        endDate: input.endDate,
        calendarIds: input.calendarIds,
      })
      const data = requireBridgeData(response)
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
    },
  )
}
