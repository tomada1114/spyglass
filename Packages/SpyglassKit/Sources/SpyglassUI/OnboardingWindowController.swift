import AppKit
import os
import SpyglassCore
import SwiftUI

/// Owns the onboarding window (440 × 640, hidden title bar, close-only) and
/// scopes the Screen Recording poll to its visibility.
///
/// A plain `NSWindow` owner rather than an `NSWindowController` subclass —
/// there is no nib/coder path to support, and the template bans dead
/// `init?(coder:)` stubs in spirit (no force-unwraps, no fatalError).
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private enum Metrics {
        static let width: CGFloat = 440
        static let height: CGFloat = 640
    }

    private static let logger = Logger(
        subsystem: "io.github.tomada1114.Spyglass",
        category: "onboarding",
    )

    private let permissions: PermissionsService
    private let settings: SettingsStore
    private let loginItems: LoginItemService
    private var window: NSWindow?
    private var finishedViaCTA = false

    /// Wires the controller to the app-wide services it presents.
    public init(
        permissions: PermissionsService,
        settings: SettingsStore,
        loginItems: LoginItemService,
    ) {
        self.permissions = permissions
        self.settings = settings
        self.loginItems = loginItems
    }

    /// Shows (or re-fronts) the window and starts permission monitoring.
    public func show() {
        finishedViaCTA = false
        let onboardingWindow = window ?? makeWindow()
        window = onboardingWindow
        permissions.refresh()
        permissions.startMonitoring()
        onboardingWindow.center()
        onboardingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The 1 s poll must die with the window (idle CPU stays at zero), and
    /// closing with everything granted counts as accepting the CTA.
    public func windowWillClose(_: Notification) {
        permissions.stopMonitoring()
        guard !finishedViaCTA, permissions.model.onboardingCTA == .startPeeking else {
            return
        }
        applyLoginItemChoice()
    }

    private func makeWindow() -> NSWindow {
        let onboardingWindow = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: Metrics.width, height: Metrics.height),
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )
        onboardingWindow.titlebarAppearsTransparent = true
        onboardingWindow.titleVisibility = .hidden
        onboardingWindow.isReleasedWhenClosed = false
        onboardingWindow.delegate = self
        // The window-content identifier lives on the AppKit view: a SwiftUI
        // root-level accessibilityIdentifier would cascade onto every child
        // element and clobber the CTA/row identifiers.
        onboardingWindow.contentViewController = NSHostingController(
            rootView: OnboardingView(
                permissions: permissions,
                settings: settings,
                loginItems: loginItems,
            ) { [weak self] in
                self?.finishedViaCTA = true
                self?.window?.close()
            },
        )
        onboardingWindow.contentView?.setAccessibilityIdentifier("onboardingWindow")
        return onboardingWindow
    }

    /// Same behavior as the CTA, but errors can only be logged here — the
    /// window is already on its way out.
    private func applyLoginItemChoice() {
        do {
            try loginItems.setEnabled(settings.launchAtLogin)
        } catch {
            Self.logger.error(
                "login item registration on close failed: \(error.localizedDescription)",
            )
        }
    }
}
