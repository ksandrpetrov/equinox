import Foundation

enum SettingsTab: Hashable, CaseIterable {
    case general
    case calendars
    case appearance
    case privacy
    case shortcuts
    case mcp
    case plaud
    case about

    var searchKeywords: [String] {
        switch self {
        case .general:
            ["general", "launch", "login", "startup", "panel", "pin", "agenda", "days"]
        case .calendars:
            ["calendars", "calendar", "filter", "source", "select"]
        case .appearance:
            ["appearance", "theme", "dark", "light", "size", "icon", "menu bar", "glass"]
        case .privacy:
            ["privacy", "calendar access", "permission", "tcc"]
        case .shortcuts:
            ["shortcuts", "keyboard", "hotkey"]
        case .mcp:
            ["mcp", "cursor", "codex", "claude", "ai", "llm", "bridge", "node"]
        case .plaud:
            ["plaud", "recording", "oauth", "connect", "integration"]
        case .about:
            ["about", "version", "equinox"]
        }
    }
}
