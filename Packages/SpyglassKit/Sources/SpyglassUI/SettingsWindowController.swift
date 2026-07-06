import AppKit
import SpyglassCore
import SwiftUI

/// Owns the fixed 400 × 360 settings window (standard titlebar, close-only).
@MainActor
public final class SettingsWindowController {
    private enum Metrics {
        static let width: CGFloat = 400
        static let height: CGFloat = 360
    }

    private let settings: SettingsStore
    private let loginItems: LoginItemService
    private var window: NSWindow?

    /// Wires the controller to persistence and the login item service.
    public init(settings: SettingsStore, loginItems: LoginItemService) {
        self.settings = settings
        self.loginItems = loginItems
    }

    /// Shows (or re-fronts) the settings window.
    public func show() {
        let settingsWindow = window ?? makeWindow()
        window = settingsWindow
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let settingsWindow = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: Metrics.width, height: Metrics.height),
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false,
        )
        settingsWindow.title = "Spyglass Settings"
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()
        settingsWindow.contentViewController = NSHostingController(
            rootView: SettingsView(settings: settings, loginItems: loginItems),
        )
        return settingsWindow
    }
}
