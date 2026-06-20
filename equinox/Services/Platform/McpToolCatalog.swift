import Foundation

struct McpToolCatalogEntry: Identifiable {
    let id: String
    let title: String
    let description: String
}

enum McpToolCatalog {
    enum Category: CaseIterable {
        case access
        case events
        case analytics
        case plaud

        var title: String {
            switch self {
            case .access:
                return String(localized: "Calendar access", comment: "MCP tool category")
            case .events:
                return String(localized: "Events", comment: "MCP tool category")
            case .analytics:
                return String(localized: "Schedule analysis", comment: "MCP tool category")
            case .plaud:
                return String(localized: "Plaud recordings", comment: "MCP tool category")
            }
        }

        var tools: [McpToolCatalogEntry] {
            switch self {
            case .access:
                return [
                    McpToolCatalogEntry(
                        id: "get_calendar_access_status",
                        title: String(localized: "Check calendar access", comment: "MCP tool title"),
                        description: String(
                            localized: "Checks whether the AI assistant is allowed to read your calendars, without showing a permission dialog. Use this first to see if setup worked.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "request_calendar_access",
                        title: String(localized: "Request calendar access", comment: "MCP tool title"),
                        description: String(
                            localized: "Asks macOS for permission to access calendars through Equinox. May show a system dialog.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "list_calendars",
                        title: String(localized: "List calendars", comment: "MCP tool title"),
                        description: String(
                            localized: "Shows all calendars on your Mac — work, personal, shared, and so on — with name, color, and whether new events can be added.",
                            comment: "MCP tool description"
                        )
                    ),
                ]
            case .events:
                return [
                    McpToolCatalogEntry(
                        id: "list_events",
                        title: String(localized: "List events", comment: "MCP tool title"),
                        description: String(
                            localized: "Shows meetings and appointments for a date range you choose (for example, a day or a week). Can be limited to specific calendars. Up to 500 events per request.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "get_event",
                        title: String(localized: "Event details", comment: "MCP tool title"),
                        description: String(
                            localized: "Opens full details of one meeting: time, location, notes, participants, and video call link if present.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "create_event",
                        title: String(localized: "Create event", comment: "MCP tool title"),
                        description: String(
                            localized: "Adds a new meeting or appointment to your calendar when you ask the assistant to schedule something.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "update_event",
                        title: String(localized: "Update event", comment: "MCP tool title"),
                        description: String(
                            localized: "Changes an existing meeting — for example, moves it to another time or updates the title, location, or notes.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "delete_event",
                        title: String(localized: "Delete event", comment: "MCP tool title"),
                        description: String(
                            localized: "Removes a meeting from the calendar. For repeating events, you can delete only one occurrence or all future ones.",
                            comment: "MCP tool description"
                        )
                    ),
                ]
            case .analytics:
                return [
                    McpToolCatalogEntry(
                        id: "analyze_schedule",
                        title: String(localized: "Analyze schedule", comment: "MCP tool title"),
                        description: String(
                            localized: "Calculates how busy you are: minutes in meetings, share of the day filled, how many calls have a video link, and all-day events versus timed meetings.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "find_conflicts",
                        title: String(localized: "Find conflicts", comment: "MCP tool title"),
                        description: String(
                            localized: "Finds meetings that overlap in time — double bookings you may want to resolve.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "find_free_time",
                        title: String(localized: "Find free time", comment: "MCP tool title"),
                        description: String(
                            localized: "Finds open time windows during work hours (by default 9:00–18:00) that are long enough for a new meeting.",
                            comment: "MCP tool description"
                        )
                    ),
                ]
            case .plaud:
                return [
                    McpToolCatalogEntry(
                        id: "get_plaud_status",
                        title: String(localized: "Check Plaud cache", comment: "MCP tool title"),
                        description: String(
                            localized: "Checks whether Equinox has a local Plaud recording catalog and cached links between recordings and calendar events.",
                            comment: "MCP tool description"
                        )
                    ),
                    McpToolCatalogEntry(
                        id: "list_plaud_recordings",
                        title: String(localized: "List Plaud recordings", comment: "MCP tool title"),
                        description: String(
                            localized: "Shows Plaud recordings from the local Equinox cache for a day or date range, including cached calendar event matches when available.",
                            comment: "MCP tool description"
                        )
                    ),
                ]
            }
        }
    }

    static var groups: [(category: Category, tools: [McpToolCatalogEntry])] {
        Category.allCases.map { ($0, $0.tools) }
    }

    static var allToolIDs: [String] {
        groups.flatMap(\.tools).map(\.id)
    }
}
