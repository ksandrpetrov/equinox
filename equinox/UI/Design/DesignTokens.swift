import SwiftUI

enum EquinoxDesign {
    static let spacingMicro: CGFloat = 2
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20

    static let radiusSM: CGFloat = 8
    static let radiusLG: CGFloat = 14
    static let chipRadius: CGFloat = 4

    static let panelCornerRadius: CGFloat = 18
    static let panelPadding: CGFloat = 16
    static let panelAgendaMaxHeight: CGFloat = 400
    static let panelDefaultHeight: CGFloat = 520
    static let panelPopoverOffset: CGFloat = 6
    static let panelScreenMargin: CGFloat = 10
    static let sectionSpacing: CGFloat = 8

    static let cellRadius: CGFloat = 8
    static let cardRadius: CGFloat = 12
    static let hairlineWidth: CGFloat = 0.5
    static let monthBoundaryWidth: CGFloat = 0.5
    static let selectionStrokeWidth: CGFloat = 1
    static let focusStrokeWidth: CGFloat = 2
    static let eventMarkerRowHeight: CGFloat = 12

    static var toolbarButtonSize: CGFloat { SizeMetrics.metrics(for: .medium).toolbarButtonSize }
    static let minimumReadableFontSize: CGFloat = 10

    static let settingsSidebarWidth: CGFloat = 220
    static let settingsSectionSpacing: CGFloat = 24
    static let settingsDetailPadding: CGFloat = 24
    static let settingsRowVerticalPadding: CGFloat = 10
    static let settingsCalendarListMinHeight: CGFloat = 200

    static let hoverAnimation = Animation.snappy(duration: 0.2)
    static let expandAnimation = Animation.smooth(duration: 0.22)

    static let pressScale: CGFloat = 0.97
    static let onAccentForeground = Color("OnAccentForeground", bundle: .equinox)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    enum ColorToken {
        static let accent = Color("AccentColor", bundle: .equinox)
        static let accentStrong = Color("AccentStrong", bundle: .equinox)
        static let solar = Color("SolarAccent", bundle: .equinox)
        static var action: Color { accent }
        static var actionStrong: Color { accentStrong }
        static var present: Color { solar }
        static let surfacePrimary = surfaceColor(light: 0xEFF0F2, dark: 0x343638)
        static let surfaceSecondary = surfaceColor(light: 0xE8EAED, dark: 0x393C40)
        static let surfaceWindow = surfacePrimary
        static let surfaceRaised = surfaceColor(light: 0xF8F9FA, dark: 0x42464B)
        static let textPrimary = surfaceColor(light: 0x1D1D1F, dark: 0xF5F5F7)
        static let weekendTint = Color("WeekendTint", bundle: .equinox)
        static let monthBoundary = Color("MonthBoundary", bundle: .equinox)
        static let semanticRed = Color("SemanticRed", bundle: .equinox)
        static let semanticOrange = Color("SemanticOrange", bundle: .equinox)
        static let semanticGreen = Color("SemanticGreen", bundle: .equinox)
        static let semanticBlue = Color("SemanticBlue", bundle: .equinox)
        static let warning = semanticOrange
        static let success = semanticGreen
        static let error = semanticRed

        static var accentSoft: Color { accent.opacity(0.16) }
        static var accentRing: Color { accent }
        static let focusRing = Color(nsColor: .keyboardFocusIndicatorColor)

        static let hairlineBorder = Color.primary.opacity(0.12)
        static let separator = Color.primary.opacity(0.12)
        static let interactionRest = Color.primary.opacity(0.06)
        static let interactionHover = Color.primary.opacity(0.08)
        static let interactionPress = Color.primary.opacity(0.10)
        static let interactionSubtle = Color.primary.opacity(0.04)
        static let pickerUnselected = Color.primary.opacity(0.03)

        static var weekdayDimmed: Color { Color.secondary.opacity(EquinoxDesign.StateOpacity.weekdayDimmed) }

        private static func surfaceColor(light: UInt32, dark: UInt32) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
                return NSColor(
                    srgbRed: Double((hex >> 16) & 0xff) / 255,
                    green: Double((hex >> 8) & 0xff) / 255,
                    blue: Double(hex & 0xff) / 255,
                    alpha: 1
                )
            })
        }
    }

    enum EventStripe {
        static let width: CGFloat = 3
        static let widthHero: CGFloat = 4
        static let cornerRadius: CGFloat = 2
    }

    enum ChipMetrics {
        static let detailDotSize: CGFloat = 7
        static let badgeHorizontalPadding: CGFloat = 7
        static let badgeVerticalPadding: CGFloat = 3
    }

    enum ControlWidth {
        static let settingsPicker: CGFloat = 160
        static let weekdayCell: CGFloat = 32
        static let weekdayCellHeight: CGFloat = 28
        static let shortcutRecorder: CGFloat = 160
        static let shortcutRecorderHeight: CGFloat = 28
        static let trailingLabel: CGFloat = 24
        static let metadataIcon: CGFloat = 28
        static let aboutLogo: CGFloat = 96
        static let menuBarPickerPreviewHeight: CGFloat = 20
        static let calendarColorDot: CGFloat = 10
        static let joinIcon: CGFloat = 36
    }

    enum StateOpacity {
        static let disabled: Double = 0.5
        static let declined: Double = 0.65
        static let declinedEvent: Double = 0.72
        static let declinedTitle: Double = 0.55
        static let notesBody: Double = 0.9
        static let joinSubtitle: Double = 0.85
        static let weekendHighlight: Double = 0.10
        static let glassTint: Double = 0.55
        static let badgeTint: Double = 0.12
        static let badgeBorder: Double = 0.25
        static let chipForegroundSubtle: Double = 0.85
        static let weekdayDimmed: Double = 0.7
        static let warningBannerTint: Double = 0.08
        static let currentEventBackground: Double = 0.10
        static let monthBoundary: Double = 0.55
    }

    static func weekdayHeaderFont() -> Font {
        .caption2.weight(.semibold)
    }

    static func weekNumberFont(size: CGFloat) -> Font {
        .system(size: size - 2, weight: .medium, design: .monospaced)
    }

    static func weekdayHeaderTracking(fontSize: CGFloat = 10) -> CGFloat {
        fontSize * 0.04
    }

    static func dayNumeralFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    static func calendarTitleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func calendarYearFont(size: CGFloat) -> Font {
        .system(size: size - 1, weight: .medium).monospacedDigit()
    }

    static func agendaSectionTitleFont(size: CGFloat) -> Font {
        .system(size: size + 1, weight: .semibold)
    }

    static func agendaSectionSubtitleFont(size: CGFloat) -> Font {
        .system(size: size - 1, weight: .medium)
    }

    static func agendaEventTitleFont(size: CGFloat, isExpanded: Bool) -> Font {
        .system(size: size, weight: isExpanded ? .semibold : .medium)
    }

    static func agendaEventMetaFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func microFont(size: CGFloat = minimumReadableFontSize) -> Font {
        .system(size: size, weight: .bold)
    }

    static func sectionHeaderFont() -> Font { .headline }

    static func panelIconFont(isSelected: Bool) -> Font {
        .system(size: 13, weight: isSelected ? .semibold : .medium)
    }

    static func agendaEventCountFont() -> Font {
        .caption2.monospacedDigit().weight(.semibold)
    }

    static func monoTimeFont(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium).monospacedDigit()
    }

    static func aboutTitleFont() -> Font { .largeTitle.bold() }
}

enum MenuBarDesign {
    static let barHeight: CGFloat = 16
    static let badgeRadius: CGFloat = EquinoxDesign.chipRadius
    static let badgeHorizontalPadding: CGFloat = EquinoxDesign.spacingXS
    static let classicBadgeHorizontalPadding: CGFloat = EquinoxDesign.spacingXS + EquinoxDesign.spacingMicro
    static let classicBadgeVerticalPadding: CGFloat = EquinoxDesign.spacingMicro
    static let classicBadgeOutlineWidth: CGFloat = 0.5
    static let dateFontSize: CGFloat = 11.5
    static let clockFontSize: CGFloat = 13
    static let meetingIconSize: CGFloat = 14
    static let meetingLeadingPadding: CGFloat = 3
    static let previewHorizontalPadding: CGFloat = 6
    static let previewVerticalPadding: CGFloat = 4
    static let previewCapsuleHorizontalPadding: CGFloat = EquinoxDesign.spacingSM + 2
    static let previewCapsuleVerticalPadding: CGFloat = EquinoxDesign.spacingXS + 2

    /// Template menu bar images must rasterize as opaque black; the system tints them.
    static let templateInk = Color.black
    /// Preview renders are not template images, so they carry an explicit ink per scheme.
    static let previewInkLight = Color.black
    static let previewInkDark = Color.white

    static func dateFont(minimal: Bool) -> Font {
        .system(size: dateFontSize, weight: minimal ? .bold : .semibold)
    }

    static func meetingIconFont() -> Font {
        .system(size: meetingIconSize)
    }
}

enum ModalDesign {
    static var contentPadding: CGFloat { EquinoxDesign.spacingXL }
    static var sectionSpacing: CGFloat { EquinoxDesign.spacingLG }
    static let minHeight: CGFloat = 320
    static var cornerRadius: CGFloat { EquinoxDesign.radiusLG }
    static let confirmWidth: CGFloat = 280
}

enum SettingsDesign {
    static var sidebarWidth: CGFloat { EquinoxDesign.settingsSidebarWidth }
    static var sectionSpacing: CGFloat { EquinoxDesign.settingsSectionSpacing }
    static var sectionHeaderBottomPadding: CGFloat { EquinoxDesign.spacingSM - 2 }
    static var detailPadding: CGFloat { EquinoxDesign.settingsDetailPadding }
    static var rowVerticalPadding: CGFloat { EquinoxDesign.settingsRowVerticalPadding }

    static let windowMinWidth: CGFloat = 720
    static let windowMinHeight: CGFloat = 560

    typealias ColorToken = EquinoxDesign.ColorToken
}
