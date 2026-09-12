import SwiftUI

enum PanelStateOverlayContent: Equatable {
    case none
    case permission
    case fetchError(String)
    case noCalendarsSelected
    case noCalendarsAvailable

    static func resolve(
        accessStatus: CalendarAccessStatus,
        hasCompletedInitialLoad: Bool,
        fetchError: String?,
        hasCalendars: Bool,
        hasSelectedCalendars: Bool
    ) -> PanelStateOverlayContent {
        guard accessStatus.isAuthorized else { return .permission }
        if let fetchError { return .fetchError(fetchError) }
        guard hasCompletedInitialLoad else { return .none }
        guard hasSelectedCalendars else {
            return hasCalendars ? .noCalendarsSelected : .noCalendarsAvailable
        }
        return .none
    }
}

struct PanelStateOverlay: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: EquinoxDesign.spacingSM) {
            if shouldShowShortcutTip {
                shortcutTipBanner
            }
            switch contentState {
            case .none:
                EmptyView()
            case .permission:
                permissionBanner
            case .fetchError(let error):
                errorBanner(error)
            case .noCalendarsSelected:
                noCalendarsBanner(hasCalendars: true)
            case .noCalendarsAvailable:
                noCalendarsBanner(hasCalendars: false)
            }
        }
    }

    private var contentState: PanelStateOverlayContent {
        PanelStateOverlayContent.resolve(
            accessStatus: appState.events.calendarAccessStatus,
            hasCompletedInitialLoad: appState.events.hasCompletedInitialEventLoad,
            fetchError: appState.events.lastFetchError,
            hasCalendars: appState.events.hasCalendars,
            hasSelectedCalendars: appState.events.hasSelectedCalendars
        )
    }

    private var shouldShowShortcutTip: Bool {
        !appState.preferences.hasSeenShortcutTip
            && appState.events.calendarAccessStatus.isAuthorized
            && appState.events.lastFetchError == nil
            && appState.events.hasSelectedCalendars
    }

    private var shortcutTipBanner: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Text(String(localized: "New Event   ⌘N · Go to Today   T · Pin Equinox   P", bundle: .equinox, comment: "Shortcut tip banner"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                appState.preferences.hasSeenShortcutTip = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(EquinoxButtonStyle(variant: .plain, size: .small))
            .accessibilityLabel(String(localized: "Dismiss shortcut tip", bundle: .equinox, comment: ""))
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .equinoxCard(style: .subtle, cornerRadius: EquinoxDesign.radiusSM)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Label {
                Text(String(localized: "Calendar access required", bundle: .equinox, comment: "Permission banner title"))
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(EquinoxDesign.ColorToken.semanticOrange)
            }

            Text(permissionMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: EquinoxDesign.spacingSM) {
                    permissionActions
                }
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    permissionActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EquinoxDesign.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(EquinoxDesign.ColorToken.semanticOrange.opacity(EquinoxDesign.StateOpacity.warningBannerTint))
                .overlay {
                    RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                        .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private var permissionMessage: String {
        switch appState.events.calendarAccessStatus {
        case .notDetermined:
            String(localized: "Equinox needs access to your calendars to show events.", bundle: .equinox, comment: "Permission banner body")
        case .denied:
            String(localized: "Calendar access is off. Enable Full Access in System Settings.", bundle: .equinox, comment: "Permission denied banner body")
        case .restricted:
            String(localized: "Calendar access is restricted by system policy.", bundle: .equinox, comment: "Permission restricted banner body")
        case .authorized:
            ""
        }
    }

    @ViewBuilder
    private var permissionActions: some View {
        if appState.events.calendarAccessStatus == .notDetermined {
            Button(String(localized: "Request Access", bundle: .equinox, comment: "")) {
                appState.requestCalendarAccessIfNeeded()
            }
            .buttonStyle(EquinoxButtonStyle(variant: .prominent, size: .small))
            .fixedSize(horizontal: true, vertical: false)
        }

        Button(String(localized: "Open System Settings", bundle: .equinox, comment: "")) {
            appState.openCalendarPrivacySettings()
        }
        .buttonStyle(EquinoxButtonStyle(variant: .bordered, size: .small))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func errorBanner(_ message: String) -> some View {
        EquinoxBanner(
            message: message,
            style: .warning,
            actionTitle: String(localized: "Retry", bundle: .equinox, comment: ""),
            action: { appState.events.retryFetchEvents() }
        )
    }

    private func noCalendarsBanner(hasCalendars: Bool) -> some View {
        EquinoxBanner(
            message: hasCalendars
                ? String(localized: "No calendars selected", bundle: .equinox, comment: "No calendars banner")
                : String(localized: "No calendars available", bundle: .equinox, comment: "Calendar settings empty state"),
            style: .info,
            actionTitle: String(localized: "Calendars…", bundle: .equinox, comment: "Open calendars settings"),
            action: { SettingsActivationHandler.openSettings(appState: appState, initialTab: .calendars) }
        )
    }
}
