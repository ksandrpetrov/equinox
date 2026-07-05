import SwiftUI

enum EquinoxDesign {
    static let spacingMicro: CGFloat = 2
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 32

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 14
    static let chipRadius: CGFloat = 4
    static let capsuleRadius: CGFloat = 999

    static let panelCornerRadius: CGFloat = 14
    static let panelPadding: CGFloat = 16
    static let panelAgendaMaxHeight: CGFloat = 400
    static let panelDefaultHeight: CGFloat = 520
    static let panelPopoverOffset: CGFloat = 6
    static let panelScreenMargin: CGFloat = 10
    static let sectionSpacing: CGFloat = 8

    static let cellRadius: CGFloat = 8
    static let cardRadius: CGFloat = 10

    static let agendaHeaderTitleSpacing: CGFloat = spacingSM - 2
    static let agendaHeaderVerticalPadding: CGFloat = spacingSM - 3
    static let commandBarHeight: CGFloat = 40
    static var toolbarButtonSize: CGFloat { SizeMetrics.metrics(for: .medium).toolbarButtonSize }

    static let emptyStateIconSize: CGFloat = 32

    static let settingsSidebarWidth: CGFloat = 220
    static let settingsDetailMinWidth: CGFloat = 480
    static let settingsSectionCornerRadius: CGFloat = 12
    static let settingsSectionSpacing: CGFloat = 20
    static let settingsDetailPadding: CGFloat = 20
    static let settingsRowVerticalPadding: CGFloat = 8
    static let settingsCalendarListMinHeight: CGFloat = 200

    static let hoverAnimation = Animation.snappy(duration: 0.2)
    static let expandAnimation = Animation.smooth(duration: 0.22)

    static let pressScale: CGFloat = 0.97
    static let joinHoverScale: CGFloat = 1.01

    static let onAccentForeground = Color.white

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    static func monthTransition(forward: Bool) -> AnyTransition {
        let insertion = AnyTransition.move(edge: forward ? .trailing : .leading)
            .combined(with: .opacity)
        let removal = AnyTransition.move(edge: forward ? .leading : .trailing)
            .combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    enum ColorToken {
        static let accent = Color("AccentColor")
        static let accentStrong = Color("AccentStrong")
        static let surfacePrimary = Color("SurfacePrimary")
        static let surfaceSecondary = Color("SurfaceSecondary")
        static let surfaceWindow = Color("SurfaceWindow")
        static let surfaceRaised = Color("SurfaceRaised")
        static let weekendTint = Color("WeekendTint")
        static let monthBoundary = Color("MonthBoundary")
        static let semanticRed = Color("SemanticRed")
        static let semanticOrange = Color("SemanticOrange")
        static let semanticGreen = Color("SemanticGreen")
        static let semanticBlue = Color("SemanticBlue")
        static let warning = semanticOrange
        static let success = semanticGreen
        static let error = semanticRed

        static var accentSoft: Color { accent.opacity(0.16) }
        static var accentRing: Color { accent.opacity(0.55) }

        static let hairlineBorder = Color.primary.opacity(0.06)
        static let strongBorder = Color.primary.opacity(0.12)
        static let separator = Color.primary.opacity(0.10)
        static let interactionRest = Color.primary.opacity(0.06)
        static let interactionHover = Color.primary.opacity(0.08)
        static let interactionPress = Color.primary.opacity(0.10)
        static let interactionSubtle = Color.primary.opacity(0.04)
        static let pickerUnselected = Color.primary.opacity(0.03)

        static var weekdayDimmed: Color { Color.secondary.opacity(EquinoxDesign.StateOpacity.weekdayDimmed) }
    }

    enum ShadowToken {
        static let panelGlassOpacity: Double = 0.12
        static let panelSolidOpacity: Double = 0.06
        static let panelRadius: CGFloat = 12
        static let panelYOffset: CGFloat = 4

        static let sheetOpacity: Double = 0.22
        static let sheetRadius: CGFloat = 20
        static let sheetYOffset: CGFloat = 12

        static let joinRestOpacity: Double = 0.22
        static let joinHoverOpacity: Double = 0.35
        static let joinRadius: CGFloat = 8
        static let joinYOffset: CGFloat = 3
    }

    enum EventStripe {
        static let width: CGFloat = 3
        static let widthHero: CGFloat = 4
        static let cornerRadius: CGFloat = 2
    }

    enum ChipMetrics {
        static let dotSize: CGFloat = 6
        static let detailDotSize: CGFloat = 7
        static let spacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 3
        static let detailHorizontalPadding: CGFloat = 8
        static let detailVerticalPadding: CGFloat = 4
        static let badgeHorizontalPadding: CGFloat = 7
        static let badgeVerticalPadding: CGFloat = 3
    }

    enum ControlWidth {
        static let settingsPicker: CGFloat = 160
        static let settingsPickerNarrow: CGFloat = 140
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
        static let closeDisabled: Double = 0.45
        static let responding: Double = 0.55
        static let notesBody: Double = 0.9
        static let joinSubtitle: Double = 0.85
        static let selectionTint: Double = 0.16
        static let selectionBorder: Double = 0.35
        static let chipBackground: Double = 0.14
        static let weekendHighlight: Double = 0.25
        static let metadataIconBackground: Double = 0.12
        static let cardBackground: Double = 0.72
        static let barBackground: Double = 0.85
        static let joinGlassOverlay: Double = 0.18
        static let badgeTint: Double = 0.12
        static let badgeBorder: Double = 0.25
        static let chipForegroundSubtle: Double = 0.85
        static let weekdayDimmed: Double = 0.7
        static let warningBannerTint: Double = 0.08
    }

    static func panelTitleFont() -> Font { .title2.weight(.semibold) }

    static func weekdayHeaderFont() -> Font {
        .caption2.weight(.semibold)
    }

    static func weekdayHeaderTracking(fontSize: CGFloat = 10) -> CGFloat {
        fontSize * 0.04
    }

    static func dayNumeralFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func calendarTitleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func agendaSectionTitleFont(size: CGFloat) -> Font {
        .system(size: size + 1, weight: .semibold)
    }

    static func agendaSectionSubtitleFont(size: CGFloat) -> Font {
        .system(size: size - 1, weight: .medium)
    }

    static func microFont(size: CGFloat = 7) -> Font {
        .system(size: size, weight: .bold)
    }

    static func sectionHeaderFont() -> Font { .headline }

    static func emptyStateIconFont() -> Font {
        .system(size: emptyStateIconSize)
    }

    static func panelIconFont(isSelected: Bool) -> Font {
        .system(size: 13, weight: isSelected ? .semibold : .medium)
    }

    static func monoTimeFont(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func codeFont(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced)
    }

    static func aboutTitleFont() -> Font { .largeTitle.bold() }
}

enum MenuBarDesign {
    static let barHeight: CGFloat = 16
    static let badgeRadius: CGFloat = EquinoxDesign.chipRadius
    static let badgeHorizontalPadding: CGFloat = EquinoxDesign.spacingXS
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
    static var detailMinWidth: CGFloat { EquinoxDesign.settingsDetailMinWidth }
    static var sectionCornerRadius: CGFloat { EquinoxDesign.settingsSectionCornerRadius }
    static var sectionSpacing: CGFloat { EquinoxDesign.settingsSectionSpacing }
    static var sectionHeaderBottomPadding: CGFloat { EquinoxDesign.spacingSM - 2 }
    static var detailPadding: CGFloat { EquinoxDesign.settingsDetailPadding }
    static var rowVerticalPadding: CGFloat { EquinoxDesign.settingsRowVerticalPadding }

    static let windowMinWidth: CGFloat = 720
    static let windowMinHeight: CGFloat = 560

    typealias ColorToken = EquinoxDesign.ColorToken
}
