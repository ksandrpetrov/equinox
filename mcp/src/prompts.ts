import { z } from "zod"
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

function promptResult(text: string) {
  return {
    messages: [
      {
        role: "user" as const,
        content: {
          type: "text" as const,
          text,
        },
      },
    ],
  }
}

export function registerPrompts(server: McpServer) {
  server.registerPrompt(
    "weekly_calendar_review",
    {
      title: "Недельный обзор календаря",
      description: "Шаблон для анализа загрузки, конфликтов и встреч за неделю.",
      argsSchema: {
        startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      },
    },
    ({ startDate, endDate }) =>
      promptResult(`Сделай обзор календаря за период с ${startDate} по ${endDate}.

1. Проверь доступ: get_calendar_access_status (при необходимости request_calendar_access).
2. list_calendars — какие календари активны.
3. analyze_schedule за период — загрузка по дням и календарям.
4. find_conflicts — пересечения timed-событий.
5. find_free_time — свободные слоты в рабочие часы (09:00–18:00, минимум 30 мин).

Формат ответа:
- **Загрузка** — факты из analyze_schedule
- **Конфликты** — если есть, с eventIdentifier
- **Свободное время** — лучшие слоты для фокуса
- **Рекомендации** — 3 практических изменения на следующую неделю`),
  )

  server.registerPrompt(
    "daily_agenda",
    {
      title: "Повестка дня",
      description: "Шаблон для обзора событий и встреч одного дня.",
      argsSchema: {
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      },
    },
    ({ date }) =>
      promptResult(`Составь повестку дня на ${date}.

1. list_events за ${date}…${date}
2. Отсортируй по времени; отдельно выдели all-day события.
3. Для встреч с joinURL укажи ссылку.
4. Для встреч с hasPlaudRecording=true укажи ссылку plaudRecording.webURL.
5. find_free_time за день — где есть окна ≥30 минут между 09:00 и 18:00.

Формат:
- **All-day**
- **Расписание** (время, название, календарь, join URL, Plaud)
- **Свободные окна**
- **Риски** — плотная посадка, конфликты, поздние встречи`),
  )
}
