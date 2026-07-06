import SwiftUI

/// Fixed numbers for the permission rows (`docs/design.md` §7).
private enum Metrics {
    static let height: CGFloat = 56
    static let cornerRadius: CGFloat = 10
    static let backgroundOpacity = 0.5
    static let iconContainerSide: CGFloat = 32
    static let iconContainerCorner: CGFloat = 8
    static let iconContainerFillOpacity = 0.12
    static let iconSize: CGFloat = 16
    static let titleSize: CGFloat = 13
    static let subtitleSize: CGFloat = 12
    static let statusSize: CGFloat = 13
    static let checkSize: CGFloat = 16
    static let horizontalPadding: CGFloat = 12
    static let textSpacing: CGFloat = 2
    static let statusSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 12
    static let grantedFadeSeconds = 0.2
}

/// One permission step: leading brass icon, title/subtitle, and a trailing
/// Grant button that cross-fades into a green "Granted" state.
///
/// After the first Grant click the button falls back to the System Settings
/// deep link — the system prompt only ever appears once per install.
struct PermissionRow: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let granted: Bool
    let alreadyRequested: Bool
    let identifier: String
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: Metrics.rowSpacing) {
            iconContainer
            VStack(alignment: .leading, spacing: Metrics.textSpacing) {
                Text(title)
                    .font(.system(size: Metrics.titleSize, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: Metrics.subtitleSize))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailingStatus
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.height)
        .background(
            .quaternary.opacity(Metrics.backgroundOpacity),
            in: RoundedRectangle(cornerRadius: Metrics.cornerRadius),
        )
        .animation(.easeInOut(duration: Metrics.grantedFadeSeconds), value: granted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title): \(granted ? "granted" : "not granted")")
        .accessibilityIdentifier(identifier)
        .onChange(of: granted) { _, isGranted in
            if isGranted {
                AccessibilityNotification.Announcement("\(title): granted").post()
            }
        }
    }

    private var iconContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.iconContainerCorner)
                .fill(Color.brassPrimary.opacity(Metrics.iconContainerFillOpacity))
            Image(systemName: symbolName)
                .font(.system(size: Metrics.iconSize))
                .foregroundStyle(Color.brassPrimary)
                .accessibilityHidden(true)
        }
        .frame(width: Metrics.iconContainerSide, height: Metrics.iconContainerSide)
    }

    @ViewBuilder private var trailingStatus: some View {
        if granted {
            HStack(spacing: Metrics.statusSpacing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Metrics.checkSize))
                    .foregroundStyle(Color(nsColor: .systemGreen))
                    .accessibilityHidden(true)
                Text("Granted")
                    .font(.system(size: Metrics.statusSize))
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        } else {
            Button(alreadyRequested ? "Open System Settings…" : "Grant", action: onGrant)
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    "\(title): \(alreadyRequested ? "Open System Settings" : "Grant")",
                )
        }
    }
}
