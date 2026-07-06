import SpyglassCore
import Testing

@Suite("TriggerKeyClassifier")
struct TriggerKeyClassifierTests {
    private let classifier = TriggerKeyClassifier()

    private func flagsChanged(keyCode: UInt16, flags: KeyModifiers) -> KeyEventSnapshot {
        KeyEventSnapshot(
            keyCode: keyCode,
            isFlagsChanged: true,
            isKeyDown: false,
            rawModifierFlags: flags.rawValue,
        )
    }

    private func keyDown(keyCode: UInt16, flags: KeyModifiers = []) -> KeyEventSnapshot {
        KeyEventSnapshot(
            keyCode: keyCode,
            isFlagsChanged: false,
            isKeyDown: true,
            rawModifierFlags: flags.rawValue,
        )
    }

    // MARK: - Right Command

    @Test
    func `right command press alone engages`() {
        let event = flagsChanged(keyCode: KeyCodes.rightCommand, flags: .command)
        #expect(classifier.classify(event, trigger: .rightCommand) == .engaged)
    }

    @Test
    func `left command press does not engage`() {
        let event = flagsChanged(keyCode: KeyCodes.leftCommand, flags: .command)
        #expect(classifier.classify(event, trigger: .rightCommand) == .irrelevant)
    }

    @Test
    func `right command release is released`() {
        let event = flagsChanged(keyCode: KeyCodes.rightCommand, flags: [])
        #expect(classifier.classify(event, trigger: .rightCommand) == .released)
    }

    @Test
    func `right command with another modifier held is cancelled`() {
        let event = flagsChanged(keyCode: KeyCodes.rightCommand, flags: [.command, .shift])
        #expect(classifier.classify(event, trigger: .rightCommand) == .cancelled)
    }

    @Test
    func `another modifier pressed during the hold is cancelled`() {
        let event = flagsChanged(keyCode: 56, flags: [.command, .shift])
        #expect(classifier.classify(event, trigger: .rightCommand) == .cancelled)
    }

    @Test
    func `caps lock and keypad bits never affect the decision`() {
        let event = flagsChanged(
            keyCode: KeyCodes.rightCommand,
            flags: [.command, .capsLock, .numericPad],
        )
        #expect(classifier.classify(event, trigger: .rightCommand) == .engaged)
    }

    // MARK: - Control + Option

    @Test
    func `control plus option chord engages`() {
        let event = flagsChanged(keyCode: 58, flags: [.control, .option])
        #expect(classifier.classify(event, trigger: .controlOption) == .engaged)
    }

    @Test(arguments: [KeyModifiers.control, KeyModifiers.option, KeyModifiers([])])
    func `losing part of the control-option chord is released`(remaining: KeyModifiers) {
        let event = flagsChanged(keyCode: 58, flags: remaining)
        #expect(classifier.classify(event, trigger: .controlOption) == .released)
    }

    @Test
    func `control-option chord with an extra modifier is cancelled`() {
        let event = flagsChanged(keyCode: 56, flags: [.control, .option, .shift])
        #expect(classifier.classify(event, trigger: .controlOption) == .cancelled)
    }

    // MARK: - Fn

    @Test
    func `fn press alone engages`() {
        let event = flagsChanged(keyCode: KeyCodes.fnKey, flags: .function)
        #expect(classifier.classify(event, trigger: .fnKey) == .engaged)
    }

    @Test
    func `fn with an extra modifier does not engage`() {
        let event = flagsChanged(keyCode: KeyCodes.fnKey, flags: [.function, .shift])
        #expect(classifier.classify(event, trigger: .fnKey) == .cancelled)
    }

    @Test
    func `fn release is released`() {
        let event = flagsChanged(keyCode: KeyCodes.fnKey, flags: [])
        #expect(classifier.classify(event, trigger: .fnKey) == .released)
    }

    // MARK: - Non-modifier events

    @Test(arguments: TriggerKey.allCases)
    func `any regular key press cancels for every trigger`(trigger: TriggerKey) {
        let event = keyDown(keyCode: 0, flags: .command)
        #expect(classifier.classify(event, trigger: trigger) == .cancelled)
    }

    @Test
    func `a key-up event is irrelevant`() {
        let event = KeyEventSnapshot(
            keyCode: 0,
            isFlagsChanged: false,
            isKeyDown: false,
            rawModifierFlags: 0,
        )
        #expect(classifier.classify(event, trigger: .rightCommand) == .irrelevant)
    }

    @Test
    func `releasing an unrelated modifier while only the trigger remains is irrelevant`() {
        let event = flagsChanged(keyCode: 56, flags: .command)
        #expect(classifier.classify(event, trigger: .rightCommand) == .irrelevant)
    }
}
