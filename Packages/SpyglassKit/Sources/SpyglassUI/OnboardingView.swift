import SpyglassCore
import SwiftUI

/// Fixed numbers for the onboarding layout (`docs/design.md` §7).
private enum Metrics {
    static let width: CGFloat = 440
    static let height: CGFloat = 640
    static let horizontalPadding: CGFloat = 32
    static let sectionSpacing: CGFloat = 12
    static let titleSpacing: CGFloat = 4
    static let iconSize: CGFloat = 96
    static let titleSize: CGFloat = 28
    static let taglineSize: CGFloat = 15
    static let rowSpacing: CGFloat = 8
    static let toggleHeight: CGFloat = 44
    static let toggleFontSize: CGFloat = 13
    static let relaunchNoteSize: CGFloat = 13
    static let errorSize: CGFloat = 12
    static let topPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 24
}

/// The first-launch / permission-recovery window content
/// (`docs/wireframes.md` §1). Pure presentation: permission state comes
/// from `PermissionsService`, decisions from Core's `PermissionsModel`.
public struct OnboardingView: View {
    private let permissions: PermissionsService
    private let settings: SettingsStore
    private let loginItems: LoginItemService
    private let onFinished: () -> Void

    @State private var launchAtLogin: Bool
    @State private var screenRecordingRequested = false
    @State private var accessibilityRequested = false
    @State private var loginItemErrorVisible = false

    public var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            header
            OnboardingDemoView()
            permissionRows
            loginToggle
            ctaArea
        }
        .padding(.top, Metrics.topPadding)
        .padding(.bottom, Metrics.bottomPadding)
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(width: Metrics.width, height: Metrics.height)
    }

    private var header: some View {
        VStack(spacing: Metrics.titleSpacing) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .accessibilityHidden(true)
            Text("Spyglass")
                .font(.system(size: Metrics.titleSize, weight: .bold))
            Text("See through your front window.")
                .font(.system(size: Metrics.taglineSize))
                .foregroundStyle(.secondary)
        }
    }

    private var permissionRows: some View {
        VStack(spacing: Metrics.rowSpacing) {
            PermissionRow(
                symbolName: "record.circle",
                title: "Screen Recording",
                subtitle: "Required to show window content",
                granted: permissions.model.screenRecording,
                alreadyRequested: screenRecordingRequested,
                identifier: "screenRecordingRow",
            ) {
                if screenRecordingRequested {
                    permissions.openScreenRecordingSettings()
                } else {
                    screenRecordingRequested = true
                    permissions.requestScreenRecording()
                }
            }
            PermissionRow(
                symbolName: "accessibility",
                title: "Accessibility",
                subtitle: "Required for the trigger key",
                granted: permissions.model.accessibility,
                alreadyRequested: accessibilityRequested,
                identifier: "accessibilityRow",
            ) {
                if accessibilityRequested {
                    permissions.openAccessibilitySettings()
                } else {
                    accessibilityRequested = true
                    permissions.requestAccessibility()
                }
            }
        }
    }

    private var loginToggle: some View {
        VStack(spacing: Metrics.titleSpacing) {
            Toggle("Launch Spyglass at login", isOn: $launchAtLogin)
                .font(.system(size: Metrics.toggleFontSize))
                .frame(height: Metrics.toggleHeight)
                .onChange(of: launchAtLogin) { _, newValue in
                    settings.launchAtLogin = newValue
                }
            if loginItemErrorVisible {
                Text("Couldn't register — check System Settings › Login Items")
                    .font(.system(size: Metrics.errorSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var ctaArea: some View {
        let cta = permissions.model.onboardingCTA
        VStack(spacing: Metrics.rowSpacing) {
            BrassCTAButton(
                title: cta == .relaunch ? "Relaunch Spyglass" : "Start peeking",
                identifier: "startPeekingButton",
                action: performCTA,
            )
            .disabled(cta == .disabled)
            if cta == .relaunch {
                Text("Screen Recording needs a quick relaunch to take effect.")
                    .font(.system(size: Metrics.relaunchNoteSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Wires the view to its services; `onFinished` closes the window.
    public init(
        permissions: PermissionsService,
        settings: SettingsStore,
        loginItems: LoginItemService,
        onFinished: @escaping () -> Void,
    ) {
        self.permissions = permissions
        self.settings = settings
        self.loginItems = loginItems
        self.onFinished = onFinished
        _launchAtLogin = State(initialValue: settings.launchAtLogin)
    }

    private func performCTA() {
        switch permissions.model.onboardingCTA {
        case .disabled:
            break

        case .relaunch:
            Relauncher.relaunch()

        case .startPeeking:
            guard applyLoginItemChoice() else {
                return
            }
            onFinished()
        }
    }

    /// Applies the toggle via `SMAppService`; on failure reverts the toggle
    /// and surfaces the inline recovery text instead of closing the window.
    private func applyLoginItemChoice() -> Bool {
        do {
            try loginItems.setEnabled(launchAtLogin)
            return true
        } catch {
            launchAtLogin = loginItems.isEnabled
            loginItemErrorVisible = true
            return false
        }
    }
}
