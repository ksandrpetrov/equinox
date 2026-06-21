import SwiftUI

/// Compact join-meeting control for agenda rows and other inline contexts.
struct JoinMeetingButton: View {
    let url: URL
    let metrics: SizeMetrics
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help(String(localized: "Join meeting", comment: ""))
        .accessibilityLabel(String(localized: "Join meeting", comment: ""))
        .accessibilityHint(JoinURLPresentation.meetingDisplayName(for: url))
    }
}
