import SwiftUI

// Shared modal primitives for panel sheets and settings confirms.
// Settings window uses SettingsDetailScaffold; panel modals use ModalSheetScaffold.

enum ModalBannerStyle {
    case error
    case warning
}

struct ModalErrorBanner: View {
    let message: String
    var style: ModalBannerStyle = .error

    var body: some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingSM) {
            Image(systemName: iconName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(foregroundColor)
            Text(message)
                .font(.footnote)
                .foregroundStyle(foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .fill(backgroundColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch style {
        case .error: "exclamationmark.triangle.fill"
        case .warning: "info.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .error: .red
        case .warning: .secondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .error: Color.red.opacity(0.12)
        case .warning: Color.secondary.opacity(0.12)
        }
    }
}

struct ModalSheetScaffold<Content: View>: View {
    let title: String
    let metrics: SizeMetrics
    var cancelTitle: String = String(localized: "Cancel", comment: "Modal cancel button")
    var confirmTitle: String?
    var confirmDisabled: Bool = false
    var destructiveTitle: String?
    var minHeight: CGFloat? = ModalDesign.minHeight
    let onCancel: () -> Void
    var onConfirm: (() -> Void)?
    var onDestructive: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .toolbar {
                    if let destructiveTitle, let onDestructive {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(destructiveTitle, role: .destructive, action: onDestructive)
                        }
                    }

                    if let confirmTitle, let onConfirm {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelTitle, action: onCancel)
                                .keyboardShortcut(.cancelAction)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(confirmTitle, action: onConfirm)
                                .disabled(confirmDisabled)
                                .keyboardShortcut(.defaultAction)
                        }
                    } else {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done", comment: "Modal dismiss button"), action: onCancel)
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                }
        }
        .equinoxSheetChrome(metrics: metrics, minHeight: minHeight)
    }
}

struct ModalConfirmDialog: View {
    let title: String
    let message: String
    var confirmTitle: String = String(localized: "Confirm", comment: "Modal confirm button")
    var cancelTitle: String = String(localized: "Cancel", comment: "Modal cancel button")
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
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(ModalDesign.contentPadding)
        .frame(width: ModalDesign.confirmWidth)
        .presentationSizing(.fitted)
        .presentationBackground(.regularMaterial)
    }
}

extension View {
    func equinoxSheetChrome(metrics: SizeMetrics, minHeight: CGFloat? = ModalDesign.minHeight) -> some View {
        Group {
            if let minHeight {
                frame(width: metrics.sheetWidth)
                    .presentationSizing(.fitted)
                    .frame(minHeight: minHeight)
            } else {
                frame(width: metrics.sheetWidth)
                    .presentationSizing(.fitted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func equinoxSheetPresentation() -> some View {
        presentationBackground(.regularMaterial)
    }
}
