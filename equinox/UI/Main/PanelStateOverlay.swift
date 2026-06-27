import SwiftUI

struct PanelStateOverlay: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: EquinoxDesign.spacingSM) {
            if !appState.preferences.hasSeenShortcutTip {
                shortcutTipBanner
            }
            if !appState.events.calendarAccessStatus.isAuthorized {
                permissionBanner
            } else if let error = appState.events.lastFetchError {
                errorBanner(error)
            } else if !appState.events.hasSelectedCalendars {
                noCalendarsBanner
            }
        }
    }

    private var shortcutTipBanner: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Text(String(localized: "New Event   ⌘N · Go to Today   T · Pin Equinox   P", comment: "Shortcut tip banner"))
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
            .accessibilityLabel(String(localized: "Dismiss shortcut tip", comment: ""))
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .equinoxCard(style: .subtle, cornerRadius: EquinoxDesign.radiusSM)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Label {
                Text(String(localized: "Calendar access required", comment: "Permission banner title"))
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(EquinoxDesign.ColorToken.semanticOrange)
            }

            Text(String(localized: "Equinox needs access to your calendars to show events.", comment: "Permission banner body"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: EquinoxDesign.spacingSM) {
                Button(String(localized: "Request Access", comment: "")) {
                    appState.events.requestCalendarAccessIfNeeded()
                }
                .buttonStyle(EquinoxButtonStyle(variant: .prominent, size: .small))

                Button(String(localized: "Open System Settings", comment: "")) {
                    appState.openCalendarPrivacySettings()
                }
                .buttonStyle(EquinoxButtonStyle(variant: .bordered, size: .small))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EquinoxDesign.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(EquinoxDesign.ColorToken.semanticOrange.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                        .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ message: String) -> some View {
        EquinoxBanner(
            message: message,
            style: .warning,
            actionTitle: String(localized: "Retry", comment: ""),
            action: { appState.events.retryFetchEvents() }
        )
    }

    private var noCalendarsBanner: some View {
        EquinoxBanner(
            message: String(localized: "No calendars selected", comment: "No calendars banner"),
            style: .info,
            actionTitle: String(localized: "Calendars…", comment: "Open calendars settings"),
            action: { SettingsActivationHandler.openSettings(appState: appState, initialTab: .calendars) }
        )
    }
}
