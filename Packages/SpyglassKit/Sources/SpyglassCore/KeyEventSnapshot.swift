/// The hardware key codes trigger detection depends on.
///
/// `flagsChanged` events carry these; right vs left ⌘ is distinguishable
/// only by key code, not by modifier flags.
public enum KeyCodes {
    /// Right ⌘ — the default trigger key.
    public static let rightCommand: UInt16 = 54
    /// Left ⌘ — must never engage the right-⌘ trigger.
    public static let leftCommand: UInt16 = 55
    /// The fn/globe key.
    public static let fnKey: UInt16 = 63
}

/// Modifier-key bits, raw-value-compatible with `NSEvent.ModifierFlags`.
///
/// Redefined here (rather than imported) because Core must stay free of
/// AppKit; the raw values are ABI-stable Carbon-era constants.
public struct KeyModifiers: OptionSet, Sendable {
    public static let capsLock = Self(rawValue: 1 << 16)
    public static let shift = Self(rawValue: 1 << 17)
    public static let control = Self(rawValue: 1 << 18)
    public static let option = Self(rawValue: 1 << 19)
    public static let command = Self(rawValue: 1 << 20)
    public static let numericPad = Self(rawValue: 1 << 21)
    public static let function = Self(rawValue: 1 << 23)

    /// The bits that participate in trigger decisions — caps lock and keypad
    /// state must never engage or cancel a peek.
    public static let decisionRelevant: KeyModifiers = [
        .shift, .control, .option, .command, .function,
    ]

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

/// A platform-neutral snapshot of one keyboard event.
///
/// Core never imports AppKit, so the UI layer flattens each `NSEvent` into
/// this struct — trigger classification stays pure and unit-testable.
public struct KeyEventSnapshot: Equatable, Sendable {
    /// Hardware key code (see ``KeyCodes`` for the trigger-relevant ones).
    public let keyCode: UInt16
    /// True for a modifier-state change (`.flagsChanged`).
    public let isFlagsChanged: Bool
    /// True for a regular key press (`.keyDown`).
    public let isKeyDown: Bool
    /// Modifier flags, bit-compatible with `NSEvent.ModifierFlags.rawValue`.
    public let rawModifierFlags: UInt64

    /// Creates a snapshot; the UI layer is the only production caller.
    public init(keyCode: UInt16, isFlagsChanged: Bool, isKeyDown: Bool, rawModifierFlags: UInt64) {
        self.keyCode = keyCode
        self.isFlagsChanged = isFlagsChanged
        self.isKeyDown = isKeyDown
        self.rawModifierFlags = rawModifierFlags
    }
}
