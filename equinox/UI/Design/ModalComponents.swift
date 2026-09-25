import SwiftUI

// Shared event drawer and confirmation components.

enum ModalBannerStyle {
    case error
    case warning
}

enum EventDeletionConfirmation {
    static func title(isRecurring: Bool) -> String {
        if isRecurring {
            return String(
                localized: "Delete this occurrence?",
                bundle: .equinox, comment: "Recurring event occurrence deletion confirmation title"
            )
        }
        return String(localized: "Delete event?", bundle: .equinox, comment: "Delete event confirmation title")
    }
}

struct ModalErrorBanner: View {
    let message: String
    var style: ModalBannerStyle = .error

    var body: some View {
        EquinoxBanner(
            message: message,
            style: equinoxStyle,
            presentation: .filled
        )
    }

    private var equinoxStyle: EquinoxBannerStyle {
        switch style {
        case .error: .error
        case .warning: .warning
        }
    }
}

struct EventDrawerScaffold<Content: View>: View {
    let title: String
    let metrics: SizeMetrics
    var confirmTitle: String?
    var confirmDisabled = false
    var isConfirming = false
    var destructiveTitle: String?
    var isDestructiveInProgress = false
    var isCancelShortcutEnabled = true
    let onCancel: () -> Void
    var onConfirm: (() -> Void)?
    var onDestructive: (() -> Void)?
    @ViewBuilder let content: () -> Content

    private var isBusy: Bool { isConfirming || isDestructiveInProgress }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: EquinoxDesign.spacingSM) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(minHeight: metrics.toolbarButtonSize)
                Spacer(minLength: 0)
            }
            .padding(EquinoxDesign.panelPadding)
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if onConfirm != nil || onDestructive != nil {
                Divider()
                HStack {
                    if let destructiveTitle, let onDestructive {
                        Button(destructiveTitle, role: .destructive, action: onDestructive)
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                    }
                    Spacer()
                    if isBusy {
                        ProgressView().controlSize(.small)
                    }
                    if let confirmTitle, let onConfirm {
                        Button(confirmTitle, action: onConfirm)
                            .buttonStyle(EquinoxButtonStyle(variant: .prominent))
                            .disabled(confirmDisabled || isBusy)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(EquinoxDesign.panelPadding)
            }
        }
        .frame(width: metrics.sheetWidth)
        .overlay(alignment: .trailing) {
            Button(action: onCancel) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: EquinoxDesign.spacingMD, height: metrics.toolbarButtonSize * 4)
                    .background(EquinoxDesign.ColorToken.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))
                    .overlay {
                        RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM)
                            .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: EquinoxDesign.hairlineWidth)
                    }
                    .frame(width: metrics.toolbarButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .keyboardShortcut(isCancelShortcutEnabled ? .cancelAction : nil)
            .accessibilityLabel(String(localized: "Collapse event panel", bundle: .equinox, comment: "Close the event drawer"))
            .help(String(localized: "Collapse event panel", bundle: .equinox, comment: "Close the event drawer"))
            .offset(x: metrics.toolbarButtonSize / 2)
        }
    }
}

struct ModalConfirmDialog: View {
    let title: String
    let message: String
    var confirmTitle: String = String(localized: "Confirm", bundle: .equinox, comment: "Modal confirm button")
    var cancelTitle: String = String(localized: "Cancel", bundle: .equinox, comment: "Modal cancel button")
    var isConfirming = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModalDesign.sectionSpacing) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, role: .destructive, action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(ModalDesign.contentPadding)
        .disabled(isConfirming)
        .interactiveDismissDisabled(isConfirming)
        .frame(width: ModalDesign.confirmWidth)
        .presentationSizing(.fitted)
        .equinoxSheetPresentation()
    }
}

extension View {
    func equinoxSheetPresentation(style: BackgroundStyle = .glass) -> some View {
        presentationBackground {
            EquinoxSurface(style: style, cornerRadius: 0, showsBorder: false)
        }
    }
}
