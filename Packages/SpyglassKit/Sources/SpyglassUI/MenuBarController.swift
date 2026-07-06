import AppKit
import Observation
import SpyglassCore

/// Owns the `NSStatusItem` — AppKit rather than SwiftUI `MenuBarExtra`
/// because the warning state needs a dynamic tint and a menu item inserted
/// at the top, neither of which MenuBarExtra exposes cleanly.
@MainActor
public final class MenuBarController {
    private let permissions: PermissionsService
    private let openSettings: () -> Void
    private let openOnboarding: () -> Void
    private let statusItem: NSStatusItem

    /// Creates the status item and starts tracking permission changes so
    /// the icon flips between normal and warning automatically.
    public init(
        permissions: PermissionsService,
        openSettings: @escaping () -> Void,
        openOnboarding: @escaping () -> Void,
    ) {
        self.permissions = permissions
        self.openSettings = openSettings
        self.openOnboarding = openOnboarding
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(
                systemSymbolName: "camera.aperture",
                accessibilityDescription: "Spyglass",
            )
            icon?.isTemplate = true
            button.image = icon
        }
        observeModel()
    }

    /// Re-applies the state now and re-arms itself for the next change —
    /// the standard Observation-without-SwiftUI loop.
    private func observeModel() {
        withObservationTracking {
            apply(permissions.model.menuBarState)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }
    }

    private func apply(_ state: PermissionsModel.MenuBarState) {
        let warning = state == .warning
        statusItem.button?.contentTintColor = warning ? .systemOrange : nil
        statusItem.menu = buildMenu(warning: warning)
    }

    /// Exactly the wireframed items (§3); the warning block prepends
    /// Fix Permissions.
    private func buildMenu(warning: Bool) -> NSMenu {
        let menu = NSMenu()
        if warning {
            let fix = NSMenuItem(
                title: "Fix Permissions…",
                action: #selector(fixPermissions),
                keyEquivalent: "",
            )
            fix.target = self
            fix.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil,
            )?.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
            menu.addItem(fix)
            menu.addItem(.separator())
        }
        let about = NSMenuItem(
            title: "About Spyglass",
            action: #selector(showAbout),
            keyEquivalent: "",
        )
        about.target = self
        menu.addItem(about)
        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ",",
        )
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit Spyglass",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q",
        )
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    @objc
    private func fixPermissions() {
        openOnboarding()
    }

    @objc
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc
    private func showSettings() {
        openSettings()
    }
}
