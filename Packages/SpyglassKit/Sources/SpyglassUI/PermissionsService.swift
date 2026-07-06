import AppKit
import ApplicationServices
import Observation
import SpyglassCore

/// Reads, monitors, and requests the two TCC permissions, publishing a
/// `PermissionsModel` for the onboarding window and menu bar.
///
/// Monitoring strategy (verified against Ice/Loop, `docs/requirements.md`
/// §2.4): Screen Recording has no change notification and never hot-applies,
/// so it is polled at 1 s — but only while onboarding is visible.
/// Accessibility has a real distributed notification, re-checked after a
/// 250 ms settle delay because it can fire before `AXIsProcessTrusted()`
/// reflects the new state.
@MainActor
@Observable
public final class PermissionsService {
    private enum Timing {
        static let screenRecordingPollSeconds: TimeInterval = 1
        static let accessibilitySettleMilliseconds = 250
    }

    private enum DeepLink {
        static let prefix = "x-apple.systempreferences:com.apple.preference.security"
        static let screenRecording = "\(prefix)?Privacy_ScreenCapture"
        static let accessibility = "\(prefix)?Privacy_Accessibility"
    }

    /// The current permission state; observation drives all dependent UI.
    public private(set) var model: PermissionsModel

    /// True while Screen Recording was NOT granted when this process
    /// started — the ingredient for `grantedThisSession`.
    @ObservationIgnored private let screenRecordingAtLaunch: Bool

    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var accessibilityObserver: (any NSObjectProtocol)?

    /// Captures the launch-time permission state and subscribes to the
    /// Accessibility change notification for the app's lifetime.
    public init() {
        let screenRecording = CGPreflightScreenCaptureAccess()
        screenRecordingAtLaunch = screenRecording
        model = PermissionsModel(
            screenRecording: screenRecording,
            accessibility: AXIsProcessTrusted(),
            grantedThisSession: false,
        )
        accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(
                    for: .milliseconds(Timing.accessibilitySettleMilliseconds),
                )
                self?.refresh()
            }
        }
    }

    /// Re-reads both permissions and republishes the model.
    public func refresh() {
        let screenRecording = CGPreflightScreenCaptureAccess()
        model = PermissionsModel(
            screenRecording: screenRecording,
            accessibility: AXIsProcessTrusted(),
            grantedThisSession: screenRecording && !screenRecordingAtLaunch,
        )
    }

    /// Starts the 1 s Screen Recording poll — call when onboarding becomes
    /// visible, and balance with ``stopMonitoring()`` (idle CPU must stay
    /// at zero when no window is open).
    public func startMonitoring() {
        guard pollTimer == nil else {
            return
        }
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Timing.screenRecordingPollSeconds,
            repeats: true,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// Stops the Screen Recording poll.
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Triggers the system Screen Recording prompt (first time only; later
    /// calls are no-ops, which is why the deep link exists).
    public func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    /// Triggers the system Accessibility prompt.
    public func requestAccessibility() {
        // The literal spelling of kAXTrustedCheckOptionPrompt — the global
        // itself is a `var` and unsafe to touch under strict concurrency.
        let promptKey = "AXTrustedCheckOptionPrompt"
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refresh()
    }

    /// Opens System Settings at the Screen Recording pane.
    public func openScreenRecordingSettings() {
        openSettings(DeepLink.screenRecording)
    }

    /// Opens System Settings at the Accessibility pane.
    public func openAccessibilitySettings() {
        openSettings(DeepLink.accessibility)
    }

    private func openSettings(_ link: String) {
        guard let url = URL(string: link) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
