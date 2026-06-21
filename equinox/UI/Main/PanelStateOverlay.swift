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
            Text(String(localized: "⌘N New Event · T Today · P Pin", comment: "Shortcut tip banner"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                appState.preferences.hasSeenShortcutTip = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Dismiss shortcut tip", comment: ""))
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Label {
                Text(String(localized: "Calendar access required", comment: "Permission banner title"))
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(EquinoxDesign.ColorToken.warning)
            }

            Text(String(localized: "Equinox needs access to your calendars to show events.", comment: "Permission banner body"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: EquinoxDesign.spacingSM) {
                Button(String(localized: "Request Access", comment: "")) {
                    appState.events.requestCalendarAccessIfNeeded()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(String(localized: "Open System Settings", comment: "")) {
                    appState.openCalendarPrivacySettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EquinoxDesign.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(EquinoxDesign.ColorToken.warning.opacity(0.08))
        }
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(EquinoxDesign.ColorToken.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button(String(localized: "Retry", comment: "")) {
                appState.events.retryFetchEvents()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .fill(EquinoxDesign.ColorToken.warning.opacity(0.08))
        }
    }

    private var noCalendarsBanner: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Image(systemName: "calendar.badge.minus")
                .foregroundStyle(.secondary)
            Text(String(localized: "No calendars selected", comment: "No calendars banner"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(String(localized: "Calendars…", comment: "Open calendars settings")) {
                SettingsActivationHandler.openSettings(appState: appState, initialTab: .calendars)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}
