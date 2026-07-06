import ServiceManagement

/// Registers/unregisters the app as a login item via `SMAppService`.
@MainActor
public struct LoginItemService {
    /// Whether the app is currently registered.
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Creates the service; stateless wrapper over `SMAppService.mainApp`.
    public init() {
        // Stateless — SMAppService.mainApp is the only dependency.
    }

    /// Applies the user's choice.
    /// - Throws: whatever `SMAppService` throws; the caller reverts its
    ///   toggle and shows the inline recovery text (wireframes §6.1).
    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
