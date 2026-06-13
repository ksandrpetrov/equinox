import SwiftUI

struct MenuBarIconView: View {
    let text: String
    let iconType: Int
    let showMeetingIndicator: Bool
    let shouldShowMeetingIndicator: Bool
    var forPreview = false

    @Environment(\.colorScheme) private var colorScheme

    /// Template menu bar images must rasterize as opaque black; the system tints them.
    private static let templateInk = Color.black

    private var ink: Color {
        if forPreview {
            return colorScheme == .dark ? .white : .black
        }
        return Self.templateInk
    }

    private var outline: Bool { iconType == 1 }
    private var plain: Bool { iconType == 2 }
    private var meeting: Bool { showMeetingIndicator && shouldShowMeetingIndicator }

    var body: some View {
        HStack(spacing: 0) {
            if meeting {
                Image(iconType == 0 ? "meetOutline" : "meetSolid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .padding(.leading, 3)
            }
            dateBadge
        }
        .frame(height: 16)
        .foregroundStyle(ink)
    }

    @ViewBuilder
    private var dateBadge: some View {
        let textView = Text(text)
            .font(.system(size: 11.5, weight: iconType == 0 ? .bold : .semibold))
            .padding(.horizontal, 4)

        if plain {
            textView
        } else if outline {
            textView.background {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(ink, lineWidth: 1)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ink)
                textView
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

enum MenuBarIconRenderer {
    @MainActor
    static func iconImage(text: String, prefs: PreferencesStore, shouldShowMeetingIndicator: Bool, scale: CGFloat) -> NSImage? {
        let view = MenuBarIconView(
            text: text,
            iconType: prefs.menuBarIconType,
            showMeetingIndicator: prefs.showMeetingIndicator,
            shouldShowMeetingIndicator: shouldShowMeetingIndicator
        )
        guard let image = rasterize(view, colorScheme: .light, scale: scale) else { return nil }
        image.isTemplate = true
        return image
    }

    static func iconText(prefs: PreferencesStore, calendar: Calendar, today: CalendarDate) -> String {
        if prefs.showMonthInIcon || prefs.showDayOfWeekInIcon {
            let locale = appLocale
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
        let view = MenuBarIconView(
            text: text,
            iconType: prefs.menuBarIconType,
            showMeetingIndicator: prefs.showMeetingIndicator,
            shouldShowMeetingIndicator: false,
            forPreview: true
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
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
