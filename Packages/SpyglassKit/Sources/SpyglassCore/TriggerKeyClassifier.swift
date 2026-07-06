/// What a single keyboard event means for the configured trigger key.
public enum TriggerDecision: Equatable, Sendable {
    /// The user pressed something else — they are typing a shortcut, not peeking.
    case cancelled
    /// The trigger is now held alone — start the hold timer.
    case engaged
    /// The event does not change the trigger state.
    case irrelevant
    /// The trigger is no longer held.
    case released
}

/// Stateless per-event trigger classification.
///
/// Deliberately memoryless: ``PeekStateMachine`` owns the hold/cancel state,
/// so a `cancelled` decision while idle is simply ignored there. Engagement
/// requires the trigger's modifiers to be held *alone* — any extra modifier
/// means the user is performing a shortcut (requirements §2.1).
public struct TriggerKeyClassifier: Sendable {
    /// Creates a classifier; it holds no state.
    public init() {
        // Stateless by design — see the type-level comment.
    }

    /// Classifies one event against the configured trigger.
    public func classify(_ snapshot: KeyEventSnapshot, trigger: TriggerKey) -> TriggerDecision {
        if snapshot.isKeyDown {
            return .cancelled
        }
        guard snapshot.isFlagsChanged else {
            return .irrelevant
        }
        let held = KeyModifiers(rawValue: snapshot.rawModifierFlags)
            .intersection(.decisionRelevant)
        switch trigger {
        case .rightCommand:
            return classifyRightCommand(snapshot, held: held)

        case .fnKey:
            return classifySingleKey(
                snapshot.keyCode,
                expectedCode: KeyCodes.fnKey,
                flag: .function,
                held: held,
            )

        case .controlOption:
            let chord: KeyModifiers = [.control, .option]
            if held == chord {
                return .engaged
            }
            return held.isSubset(of: chord) ? .released : .cancelled
        }
    }

    /// Right ⌘ with the left ⌘ also down is ambiguous in the
    /// device-independent flags (both keys share `.command`), so the
    /// device-dependent bits break the tie: without them, releasing the
    /// right ⌘ under a held left ⌘ would re-read as an engagement and the
    /// lens could stick open. Events that carry no device bits (synthetic
    /// senders) fall through to the plain single-key logic unchanged.
    private func classifyRightCommand(
        _ snapshot: KeyEventSnapshot,
        held: KeyModifiers,
    ) -> TriggerDecision {
        let raw = KeyModifiers(rawValue: snapshot.rawModifierFlags)
        let leftDown = raw.contains(.deviceLeftCommand)
        let rightDown = raw.contains(.deviceRightCommand)
        if snapshot.keyCode == KeyCodes.rightCommand, held == .command, leftDown {
            return rightDown ? .cancelled : .released
        }
        if snapshot.keyCode == KeyCodes.leftCommand, leftDown, rightDown {
            return .cancelled
        }
        return classifySingleKey(
            snapshot.keyCode,
            expectedCode: KeyCodes.rightCommand,
            flag: .command,
            held: held,
        )
    }

    /// Shared logic for the single-key triggers (right ⌘ and fn), which need
    /// the key code to tell the physical key apart from its siblings.
    private func classifySingleKey(
        _ keyCode: UInt16,
        expectedCode: UInt16,
        flag: KeyModifiers,
        held: KeyModifiers,
    ) -> TriggerDecision {
        if keyCode == expectedCode {
            if held == flag {
                return .engaged
            }
            return held.contains(flag) ? .cancelled : .released
        }
        // A different modifier changed; anything held beyond the trigger's own
        // flag means a shortcut is in progress.
        return held.subtracting(flag).isEmpty ? .irrelevant : .cancelled
    }
}
