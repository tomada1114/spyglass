import SpyglassCore
import Testing

@Suite("PeekStateMachine")
struct PeekStateMachineTests {
    private var peekingWithoutTarget: [PeekStateMachine.Input] {
        [.triggerEngaged, .holdTimerFired]
    }

    private var peekingAtSeven: [PeekStateMachine.Input] {
        [.triggerEngaged, .holdTimerFired, .targetResolved(7)]
    }

    /// A machine driven into the given prefix of inputs, discarding effects.
    private func machine(after inputs: [PeekStateMachine.Input]) -> PeekStateMachine {
        var machine = PeekStateMachine()
        for input in inputs {
            _ = machine.handle(input)
        }
        return machine
    }

    // MARK: - Arming

    @Test
    func `trigger engage from idle arms and starts the hold timer`() {
        var machine = PeekStateMachine()
        #expect(machine.handle(.triggerEngaged) == [.startHoldTimer])
        #expect(machine.state == .armed)
    }

    @Test
    func `release before the hold timer cancels without ever showing the lens`() {
        var machine = machine(after: [.triggerEngaged])
        #expect(machine.handle(.triggerReleased) == [.cancelHoldTimer])
        #expect(machine.state == .idle)
    }

    @Test
    func `another key during the arm window cancels the peek`() {
        var machine = machine(after: [.triggerEngaged])
        #expect(machine.handle(.otherKeyPressed) == [.cancelHoldTimer])
        #expect(machine.state == .idle)
    }

    @Test
    func `permission loss while armed cancels the hold timer`() {
        var machine = machine(after: [.triggerEngaged])
        #expect(machine.handle(.permissionLost) == [.cancelHoldTimer])
        #expect(machine.state == .idle)
    }

    @Test
    func `hold timer firing shows the lens with no target yet`() {
        var machine = machine(after: [.triggerEngaged])
        #expect(machine.handle(.holdTimerFired) == [.showLens])
        #expect(machine.state == .peeking(target: nil))
    }

    // MARK: - Target resolution while peeking

    @Test
    func `first resolved target starts its stream`() {
        var machine = machine(after: peekingWithoutTarget)
        #expect(machine.handle(.targetResolved(7)) == [.startStream(7)])
        #expect(machine.state == .peeking(target: 7))
    }

    @Test
    func `re-resolving the same target is a no-op`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.targetResolved(7)).isEmpty)
        #expect(machine.state == .peeking(target: 7))
    }

    @Test
    func `a different target swaps streams`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.targetResolved(9)) == [.stopStream, .startStream(9)])
        #expect(machine.state == .peeking(target: 9))
    }

    @Test
    func `losing the target stops the stream and keeps peeking`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.targetResolved(nil)) == [.stopStream])
        #expect(machine.state == .peeking(target: nil))
    }

    // MARK: - Ending a peek

    @Test
    func `releasing the trigger while streaming hides the lens and stops the stream`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.triggerReleased) == [.hideLens, .stopStream])
        #expect(machine.state == .idle)
    }

    @Test
    func `releasing the trigger with no stream only hides the lens`() {
        var machine = machine(after: peekingWithoutTarget)
        #expect(machine.handle(.triggerReleased) == [.hideLens])
        #expect(machine.state == .idle)
    }

    @Test
    func `another key while peeking ends the session even though the key is held`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.otherKeyPressed) == [.hideLens, .stopStream])
        #expect(machine.state == .ended)
    }

    @Test
    func `permission loss while peeking ends the session`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.permissionLost) == [.hideLens, .stopStream])
        #expect(machine.state == .ended)
    }

    // MARK: - Click to raise

    @Test
    func `click inside the lens raises the target and ends while the key is held`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.clickedInsideLens) == [.raiseTarget(7), .hideLens, .stopStream])
        #expect(machine.state == .ended)
    }

    @Test
    func `click with nothing to raise just ends the session`() {
        var machine = machine(after: peekingWithoutTarget)
        #expect(machine.handle(.clickedInsideLens) == [.hideLens])
        #expect(machine.state == .ended)
    }

    @Test
    func `a new peek after a click requires releasing and re-pressing the trigger`() {
        var machine = machine(after: peekingAtSeven + [.clickedInsideLens])
        #expect(machine.handle(.triggerEngaged).isEmpty)
        #expect(machine.state == .ended)
        #expect(machine.handle(.triggerReleased).isEmpty)
        #expect(machine.state == .idle)
        #expect(machine.handle(.triggerEngaged) == [.startHoldTimer])
        #expect(machine.state == .armed)
    }

    // MARK: - Ignored inputs

    @Test(arguments: [
        PeekStateMachine.Input.holdTimerFired,
        .triggerReleased,
        .otherKeyPressed,
        .targetResolved(7),
        .clickedInsideLens,
        .permissionLost,
    ])
    func `idle ignores everything except trigger engagement`(input: PeekStateMachine.Input) {
        var machine = PeekStateMachine()
        #expect(machine.handle(input).isEmpty)
        #expect(machine.state == .idle)
    }

    @Test(arguments: [
        PeekStateMachine.Input.triggerEngaged,
        .holdTimerFired,
        .targetResolved(9),
        .clickedInsideLens,
        .otherKeyPressed,
        .permissionLost,
    ])
    func `ended ignores everything except trigger release`(input: PeekStateMachine.Input) {
        var machine = machine(after: peekingAtSeven + [.clickedInsideLens])
        #expect(machine.handle(input).isEmpty)
        #expect(machine.state == .ended)
    }

    @Test(arguments: [
        PeekStateMachine.Input.triggerEngaged,
        .targetResolved(7),
        .clickedInsideLens,
    ])
    func `armed ignores inputs that only make sense while peeking`(input: PeekStateMachine.Input) {
        var machine = machine(after: [.triggerEngaged])
        #expect(machine.handle(input).isEmpty)
        #expect(machine.state == .armed)
    }

    @Test
    func `peeking ignores redundant engage and timer inputs`() {
        var machine = machine(after: peekingAtSeven)
        #expect(machine.handle(.triggerEngaged).isEmpty)
        #expect(machine.handle(.holdTimerFired).isEmpty)
        #expect(machine.state == .peeking(target: 7))
    }
}
