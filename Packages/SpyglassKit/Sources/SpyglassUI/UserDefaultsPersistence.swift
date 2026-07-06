import Foundation
import SpyglassCore

/// Production `Persisting` adapter over `UserDefaults`.
///
/// Uses `object(forKey:)` casts instead of the typed `UserDefaults` getters
/// so "never written" stays distinguishable from a written zero/false —
/// `SettingsStore` owns the defaults.
public final class UserDefaultsPersistence: Persisting {
    private let defaults: UserDefaults

    /// Wraps the given defaults domain (standard for the app).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func double(forKey key: String) -> Double? {
        defaults.object(forKey: key) as? Double
    }

    public func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
