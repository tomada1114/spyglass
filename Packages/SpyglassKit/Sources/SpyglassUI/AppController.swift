import AppKit
import SpyglassCore

/// Composition root for the whole app — the App target only instantiates
/// this and calls ``start()`` from `applicationDidFinishLaunching`.
@MainActor
public final class AppController {
    /// True when launched by the XCUITest runner (see the shims below).
    private static var isUITest: Bool {
        ProcessInfo.processInfo.environment["XCUI_TEST"] == "1"
    }

    private let settings: SettingsStore
    private let permissions: PermissionsService
    private let loginItems = LoginItemService()
    private let onboarding: OnboardingWindowController
    private let settingsWindow: SettingsWindowController
    private let peek: PeekCoordinator
    private var menuBar: MenuBarController?

    /// Builds the object graph; nothing side-effecting happens until
    /// ``start()``.
    public init() {
        let store = SettingsStore(persistence: UserDefaultsPersistence())
        settings = store
        permissions = PermissionsService(simulatingDeniedPermissions: Self.isUITest)
        onboarding = OnboardingWindowController(
            permissions: permissions,
            settings: store,
            loginItems: loginItems,
        )
        settingsWindow = SettingsWindowController(settings: store, loginItems: loginItems)
        peek = PeekCoordinator(settings: store, permissions: permissions)
    }

    /// Brings the app up: menu bar, key monitors, and — when any permission
    /// is missing — the onboarding window (wireframes §5.1).
    public func start() {
        if Self.isUITest {
            // Test-visibility shim, not a behavior change: XCUITest cannot
            // see windows of an LSUIElement (accessory) app.
            NSApp.setActivationPolicy(.regular)
        }
        menuBar = MenuBarController(
            permissions: permissions,
            openSettings: { [weak self] in
                self?.settingsWindow.show()
            },
            openOnboarding: { [weak self] in
                self?.onboarding.show()
            },
        )
        peek.onPermissionProblem = { [weak self] in
            self?.onboarding.show()
        }
        peek.start()
        if permissions.model.menuBarState == .warning {
            onboarding.show()
        }
    }
}
