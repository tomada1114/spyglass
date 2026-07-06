/// Typed key-value persistence, abstracting `UserDefaults` so Core stays
/// platform-agnostic and tests can inject an in-memory dictionary.
///
/// Getters return nil for missing keys (unlike `UserDefaults.bool`, which
/// collapses "absent" into `false`) so ``SettingsStore`` can apply real
/// defaults.
public protocol Persisting: AnyObject {
    /// The stored string, or nil when the key was never written.
    func string(forKey key: String) -> String?
    /// The stored double, or nil when the key was never written.
    func double(forKey key: String) -> Double?
    /// The stored bool, or `defaultValue` when the key was never written.
    /// (Shaped this way instead of returning `Bool?` so callers can never
    /// confuse "absent" with "false".)
    func bool(forKey key: String, default defaultValue: Bool) -> Bool
    /// Persists a string.
    func set(_ value: String, forKey key: String)
    /// Persists a double.
    func set(_ value: Double, forKey key: String)
    /// Persists a bool.
    func set(_ value: Bool, forKey key: String)
}

/// The app's three settings, clamped on every read so a hand-edited defaults
/// plist can never push an invalid value into the UI or the lens.
public struct SettingsStore {
    private enum Keys {
        static let triggerKey = "triggerKey"
        static let lensDiameter = "lensDiameter"
        static let launchAtLogin = "launchAtLogin"
    }

    /// The slider bounds from requirements §2.3.
    public static let diameterRange: ClosedRange<Double> = 220 ... 460
    /// The slider step from requirements §2.3.
    public static let diameterStep: Double = 20
    /// The out-of-the-box lens diameter.
    public static let defaultDiameter: Double = 320

    private let persistence: any Persisting

    /// Which key summons the lens; unknown persisted values fall back to
    /// the default trigger rather than crashing or disabling the app.
    public var triggerKey: TriggerKey {
        get {
            persistence.string(forKey: Keys.triggerKey)
                .flatMap(TriggerKey.init(rawValue:)) ?? .rightCommand
        }
        nonmutating set {
            persistence.set(newValue.rawValue, forKey: Keys.triggerKey)
        }
    }

    /// Lens diameter in points, snapped to the nearest valid slider stop.
    public var lensDiameter: Double {
        get {
            Self.clampDiameter(
                persistence.double(forKey: Keys.lensDiameter) ?? Self.defaultDiameter,
            )
        }
        nonmutating set {
            persistence.set(Self.clampDiameter(newValue), forKey: Keys.lensDiameter)
        }
    }

    /// Whether Spyglass registers itself as a login item. Defaults to true —
    /// the onboarding toggle ships pre-checked (requirements §2.4).
    public var launchAtLogin: Bool {
        get {
            persistence.bool(forKey: Keys.launchAtLogin, default: true)
        }
        nonmutating set {
            persistence.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    /// Wraps the given persistence; production hands in a `UserDefaults`
    /// adapter, tests a dictionary.
    public init(persistence: any Persisting) {
        self.persistence = persistence
    }

    /// Snaps to the nearest multiple of ``diameterStep`` inside
    /// ``diameterRange``; idempotent by construction.
    private static func clampDiameter(_ value: Double) -> Double {
        let clamped = min(max(value, diameterRange.lowerBound), diameterRange.upperBound)
        let steps = ((clamped - diameterRange.lowerBound) / diameterStep).rounded()
        return diameterRange.lowerBound + steps * diameterStep
    }
}
