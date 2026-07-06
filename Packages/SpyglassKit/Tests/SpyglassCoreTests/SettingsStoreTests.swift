import SpyglassCore
import Testing

/// In-memory stand-in for `UserDefaults`, letting tests hand-craft corrupt
/// persisted values.
private final class MemoryPersistence: Persisting {
    var strings: [String: String] = [:]
    var doubles: [String: Double] = [:]
    var bools: [String: Bool] = [:]

    func string(forKey key: String) -> String? {
        strings[key]
    }

    func double(forKey key: String) -> Double? {
        doubles[key]
    }

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        bools[key] ?? defaultValue
    }

    func set(_ value: String, forKey key: String) {
        strings[key] = value
    }

    func set(_ value: Double, forKey key: String) {
        doubles[key] = value
    }

    func set(_ value: Bool, forKey key: String) {
        bools[key] = value
    }
}

@Suite("SettingsStore")
struct SettingsStoreTests {
    private let persistence = MemoryPersistence()

    private var store: SettingsStore {
        SettingsStore(persistence: persistence)
    }

    // MARK: - Defaults

    @Test
    func `an empty store yields the documented defaults`() {
        #expect(store.triggerKey == .rightCommand)
        #expect(store.lensDiameter == 320)
        #expect(store.launchAtLogin == true)
    }

    // MARK: - Trigger key

    @Test
    func `a persisted trigger key round-trips`() {
        store.triggerKey = .controlOption
        #expect(store.triggerKey == .controlOption)
    }

    @Test
    func `an unknown persisted trigger string falls back to right command`() {
        persistence.strings["triggerKey"] = "hyperKey"
        #expect(store.triggerKey == .rightCommand)
    }

    // MARK: - Lens diameter

    @Test
    func `a persisted diameter round-trips`() {
        store.lensDiameter = 380
        #expect(store.lensDiameter == 380)
    }

    @Test(arguments: [
        (445.0, 440.0),
        (450.0, 460.0),
        (100.0, 220.0),
        (999.0, 460.0),
        (220.0, 220.0),
        (460.0, 460.0),
    ])
    func `hand-edited diameters clamp to the nearest valid step on read`(
        persisted: Double,
        expected: Double,
    ) {
        persistence.doubles["lensDiameter"] = persisted
        #expect(store.lensDiameter == expected)
    }

    @Test
    func `clamping is idempotent`() {
        persistence.doubles["lensDiameter"] = 445
        let once = store.lensDiameter
        persistence.doubles["lensDiameter"] = once
        #expect(store.lensDiameter == once)
    }

    // MARK: - Launch at login

    @Test
    func `a persisted launch-at-login choice round-trips`() {
        store.launchAtLogin = false
        #expect(store.launchAtLogin == false)
    }
}
