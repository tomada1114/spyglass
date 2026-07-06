/// Combines the two TCC permission states into the app's derived UI states.
///
/// `grantedThisSession` exists because Screen Recording does not hot-apply:
/// a grant made while the process is alive only works after a relaunch, so
/// the onboarding CTA must offer the relaunch instead of a dead
/// "Start peeking" button.
public struct PermissionsModel: Equatable, Sendable {
    /// What the single onboarding primary button should be.
    public enum OnboardingCTA: Equatable, Sendable {
        /// Greyed out — at least one permission is still missing.
        case disabled
        /// "Relaunch Spyglass" — capture cannot work until then.
        case relaunch
        /// "Start peeking" — everything usable right now.
        case startPeeking
    }

    /// How the menu bar icon presents itself.
    public enum MenuBarState: Equatable, Sendable {
        /// Template icon, no tint.
        case normal
        /// Orange tint + "Fix Permissions…" menu item.
        case warning
    }

    /// `CGPreflightScreenCaptureAccess()` at evaluation time.
    public let screenRecording: Bool
    /// `AXIsProcessTrusted()` at evaluation time.
    public let accessibility: Bool
    /// True when Screen Recording flipped to granted during this process's
    /// lifetime (it will not take effect until relaunch).
    public let grantedThisSession: Bool

    /// The relaunch requirement trumps everything: even with both
    /// permissions granted, an in-session Screen Recording grant cannot
    /// capture until the app restarts.
    public var onboardingCTA: OnboardingCTA {
        if screenRecording, grantedThisSession {
            return .relaunch
        }
        if screenRecording, accessibility {
            return .startPeeking
        }
        return .disabled
    }

    /// Warning whenever either permission is missing — the onboarding
    /// window must stay reachable forever (macOS re-prompts periodically).
    public var menuBarState: MenuBarState {
        screenRecording && accessibility ? .normal : .warning
    }

    /// Bundles the raw permission reads; see the type comment for why the
    /// session flag is part of the model.
    public init(screenRecording: Bool, accessibility: Bool, grantedThisSession: Bool) {
        self.screenRecording = screenRecording
        self.accessibility = accessibility
        self.grantedThisSession = grantedThisSession
    }
}
