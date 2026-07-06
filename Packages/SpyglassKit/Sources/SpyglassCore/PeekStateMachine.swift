/// The peek session state machine — the pure heart of the product.
///
/// Mirrors the diagram in `docs/wireframes.md` §5.2. Timers, streams, and
/// windows live in the UI layer; this type only decides *what should happen*
/// and returns it as ``Effect`` values, which keeps every transition
/// unit-testable.
///
/// The `ended` state exists to enforce "a new peek requires a fresh key
/// press": after a click or cancel while the trigger is still physically
/// held, the machine parks there until the trigger is released.
public struct PeekStateMachine: Equatable, Sendable {
    /// Where the session currently is.
    public enum State: Equatable, Sendable {
        /// Trigger held, 150 ms hold timer running, no lens yet.
        case armed
        /// Session over but the trigger is still held down.
        case ended
        /// No trigger held.
        case idle
        /// Lens visible; `target` is the streamed window, nil while empty.
        case peeking(target: WindowID?)
    }

    /// External happenings the machine reacts to.
    public enum Input: Equatable, Sendable {
        /// Left mouse click landed inside the lens circle.
        case clickedInsideLens
        /// The 150 ms hold threshold elapsed.
        case holdTimerFired
        /// A non-trigger key or extra modifier went down.
        case otherKeyPressed
        /// Screen Recording or Accessibility was revoked mid-session.
        case permissionLost
        /// The resolver produced a new target (nil = nothing beneath).
        case targetResolved(WindowID?)
        /// The configured trigger is now held alone.
        case triggerEngaged
        /// The configured trigger was let go.
        case triggerReleased
    }

    /// Side effects the UI layer must perform, in order.
    public enum Effect: Equatable, Sendable {
        /// Abort the pending hold timer.
        case cancelHoldTimer
        /// Dismiss the lens overlay.
        case hideLens
        /// Raise and activate the window, then let the session die.
        case raiseTarget(WindowID)
        /// Present the lens overlay (empty until a stream delivers).
        case showLens
        /// Schedule the 150 ms hold threshold.
        case startHoldTimer
        /// Begin streaming the window's content into the lens.
        case startStream(WindowID)
        /// Tear down the current stream.
        case stopStream
    }

    /// The current state, exposed read-only for tests and diagnostics.
    public private(set) var state: State = .idle

    /// Creates a machine at `idle`.
    public init() {
        // All state lives in `state`; nothing to configure.
    }

    /// Advances the machine and returns the effects to perform, in order.
    public mutating func handle(_ input: Input) -> [Effect] {
        switch state {
        case .idle:
            handleIdle(input)

        case .armed:
            handleArmed(input)

        case let .peeking(target):
            handlePeeking(input, target: target)

        case .ended:
            handleEnded(input)
        }
    }

    private mutating func handleIdle(_ input: Input) -> [Effect] {
        guard input == .triggerEngaged else {
            return []
        }
        state = .armed
        return [.startHoldTimer]
    }

    private mutating func handleArmed(_ input: Input) -> [Effect] {
        switch input {
        case .holdTimerFired:
            state = .peeking(target: nil)
            return [.showLens]

        case .otherKeyPressed, .permissionLost, .triggerReleased:
            state = .idle
            return [.cancelHoldTimer]

        case .clickedInsideLens, .targetResolved, .triggerEngaged:
            return []
        }
    }

    private mutating func handlePeeking(_ input: Input, target: WindowID?) -> [Effect] {
        // Emitted only when a stream is actually running.
        let stopIfStreaming: [Effect] = target == nil ? [] : [.stopStream]
        switch input {
        case let .targetResolved(newTarget):
            guard newTarget != target else {
                return []
            }
            state = .peeking(target: newTarget)
            guard let newTarget else {
                return stopIfStreaming
            }
            return stopIfStreaming + [.startStream(newTarget)]

        case .triggerReleased:
            state = .idle
            return [.hideLens] + stopIfStreaming

        case .otherKeyPressed, .permissionLost:
            state = .ended
            return [.hideLens] + stopIfStreaming

        case .clickedInsideLens:
            state = .ended
            guard let target else {
                return [.hideLens]
            }
            return [.raiseTarget(target), .hideLens, .stopStream]

        case .holdTimerFired, .triggerEngaged:
            return []
        }
    }

    private mutating func handleEnded(_ input: Input) -> [Effect] {
        if input == .triggerReleased {
            state = .idle
        }
        return []
    }
}
