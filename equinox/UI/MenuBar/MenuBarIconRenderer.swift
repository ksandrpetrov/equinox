import SwiftUI

struct MenuBarIconView: View {
    let text: String
    let iconStyle: MenuBarIconStyle
    let showMeetingIndicator: Bool
    let shouldShowMeetingIndicator: Bool
    var forPreview = false

    @Environment(\.colorScheme) private var colorScheme

    private var ink: Color {
        if forPreview {
            return colorScheme == .dark ? MenuBarDesign.previewInkDark : MenuBarDesign.previewInkLight
        }
        return MenuBarDesign.templateInk
    }

    private var outline: Bool { iconStyle == .classic }
    private var plain: Bool { iconStyle == .compact }
    private var meeting: Bool { showMeetingIndicator && shouldShowMeetingIndicator }

    var body: some View {
        HStack(spacing: 0) {
            if meeting {
                MenuBarMeetingGlyph(filled: iconStyle != .minimal)
                    .padding(.leading, MenuBarDesign.meetingLeadingPadding)
            }
            dateBadge
        }
        .frame(height: MenuBarDesign.barHeight)
        .foregroundStyle(ink)
    }

    @ViewBuilder
    private var dateBadge: some View {
        let textView = Text(text)
            .font(MenuBarDesign.dateFont(minimal: iconStyle == .minimal))
            .padding(.horizontal, MenuBarDesign.badgeHorizontalPadding)

        if plain {
            textView
        } else if outline {
            textView.background {
                RoundedRectangle(cornerRadius: MenuBarDesign.badgeRadius, style: .continuous)
                    .strokeBorder(ink, lineWidth: 1)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarDesign.badgeRadius, style: .continuous)
                    .fill(ink)
                textView
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

/// Shared meeting indicator glyph so the menu bar icon and hidden-icon fallback
/// stay visually identical. Rendered as a template so the system tints it.
struct MenuBarMeetingGlyph: View {
    var filled: Bool = true

    var body: some View {
        Image(systemName: filled ? "video.fill" : "video")
            .font(MenuBarDesign.meetingIconFont())
            .symbolRenderingMode(.monochrome)
            .frame(width: MenuBarDesign.meetingIconSize, height: MenuBarDesign.meetingIconSize)
    }
}

enum MenuBarIconRenderer {
    @MainActor
    static func iconImage(text: String, prefs: PreferencesStore, shouldShowMeetingIndicator: Bool, scale: CGFloat) -> NSImage? {
        let view = MenuBarIconView(
            text: text,
            iconStyle: MenuBarIconStyle(rawValue: prefs.menuBarIconType) ?? .minimal,
            showMeetingIndicator: prefs.showMeetingIndicator,
            shouldShowMeetingIndicator: shouldShowMeetingIndicator
        )
        guard let image = rasterize(view, colorScheme: .light, scale: scale) else { return nil }
        image.isTemplate = true
        return image
    }

    /// Standalone meeting indicator for the hidden-icon menu bar fallback.
    @MainActor
    static func meetingIndicatorImage(scale: CGFloat) -> NSImage? {
        let view = MenuBarMeetingGlyph()
            .foregroundStyle(MenuBarDesign.templateInk)
            .frame(height: MenuBarDesign.barHeight)
        guard let image = rasterize(view, colorScheme: .light, scale: scale) else { return nil }
        image.isTemplate = true
        return image
    }

    @MainActor
    static func iconText(prefs: PreferencesStore, calendar: Calendar, today: CalendarDate) -> String {
        if prefs.showMonthInIcon || prefs.showDayOfWeekInIcon {
            let locale = EquinoxFormatters.appLocale
            var template = "d"
            if prefs.showMonthInIcon { template += "MMM" }
            if prefs.showDayOfWeekInIcon { template += "EEE" }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
            return formatter.string(from: today.date(in: calendar))
        }
        return "\(today.day)"
    }

    @MainActor
    static func previewImage(text: String, prefs: PreferencesStore, colorScheme: ColorScheme) -> NSImage? {
        previewImage(
            text: text,
            iconStyle: MenuBarIconStyle(rawValue: prefs.menuBarIconType) ?? .minimal,
            showMeetingIndicator: prefs.showMeetingIndicator,
            colorScheme: colorScheme
        )
    }

    @MainActor
    static func previewImage(text: String, iconStyle: MenuBarIconStyle, showMeetingIndicator: Bool, colorScheme: ColorScheme) -> NSImage? {
        let view = MenuBarIconView(
            text: text,
            iconStyle: iconStyle,
            showMeetingIndicator: showMeetingIndicator,
            shouldShowMeetingIndicator: false,
            forPreview: true
        )
        .padding(.horizontal, MenuBarDesign.previewHorizontalPadding)
        .padding(.vertical, MenuBarDesign.previewVerticalPadding)
        return rasterize(view, colorScheme: colorScheme, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    /// Rasterizes a view at the display's pixel scale so text stays crisp in the
    /// menu bar instead of being rendered at 1x and upscaled by the system.
    @MainActor
    private static func rasterize(_ view: some View, colorScheme: ColorScheme, scale: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, colorScheme))
        renderer.isOpaque = false
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        let size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return NSImage(cgImage: cgImage, size: size)
    }
}
