import SwiftUI

enum EquinoxDesign {
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 14

    static let panelCornerRadius: CGFloat = 14
    static let panelPadding: CGFloat = 16
    static let panelAgendaMaxHeight: CGFloat = 400
    static let panelDefaultHeight: CGFloat = 520
    static let panelPopoverOffset: CGFloat = 6
    static let panelScreenMargin: CGFloat = 10
    static let sectionSpacing: CGFloat = 8

    static let cellRadius: CGFloat = 8
    static let cardRadius: CGFloat = 10
    static let commandBarHeight: CGFloat = 40
    static let toolbarButtonSize: CGFloat = 28

    static let settingsSidebarWidth: CGFloat = 220
    static let settingsDetailMinWidth: CGFloat = 480
    static let settingsSectionCornerRadius: CGFloat = 12
    static let settingsSectionSpacing: CGFloat = 20
    static let settingsDetailPadding: CGFloat = 20
    static let settingsRowVerticalPadding: CGFloat = 8

    static let hoverAnimation = Animation.snappy(duration: 0.2)
    static let expandAnimation = Animation.smooth(duration: 0.22)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    enum ColorToken {
        static let surfacePrimary = Color("SurfacePrimary")
        static let surfaceSecondary = Color("SurfaceSecondary")
        static let todayAccent = Color("TodayAccent")
        static let weekendTint = Color("WeekendTint")
        static let highlightedDOWBackground = Color("HighlightedDOWBackgroundColor")
        static let monthBoundary = Color("MonthBoundary")
        static let pendingBackground = Color("PendingBackgroundColor")
    }

    static func panelTitleFont() -> Font { .title2.weight(.semibold) }
    static func sectionHeaderFont() -> Font { .headline }
    static func monoTimeFont(size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
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
