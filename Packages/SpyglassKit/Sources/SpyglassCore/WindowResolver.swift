import CoreGraphics

/// The pair of windows a peek operates on: the window under the cursor and
/// the one directly beneath it.
public struct PeekTarget: Equatable, Sendable {
    /// The topmost eligible window at the cursor point.
    public let front: WindowInfo
    /// The next eligible window beneath ``front`` at the same point — the one
    /// the lens reveals.
    public let target: WindowInfo

    /// Groups the resolved pair; produced by ``WindowResolver/resolve(at:windows:)``.
    public init(front: WindowInfo, target: WindowInfo) {
        self.front = front
        self.target = target
    }
}

/// Resolves what the lens should show at a cursor point.
///
/// Pure function over an injected window snapshot so every filter rule from
/// requirements §2.1 is unit-testable without touching the window server.
public struct WindowResolver: Sendable {
    /// The outcome of a resolution attempt at one point.
    public enum Resolution: Equatable, Sendable {
        /// A window is under the cursor but nothing eligible lies beneath it.
        case frontOnly(WindowInfo)
        /// No eligible window is under the cursor at all (desktop).
        case nothing
        /// Both roles resolved — the lens can stream `target`.
        case peek(PeekTarget)
    }

    /// Windows smaller than this on either axis are decorations or helper
    /// surfaces, never peek candidates (requirements §2.1).
    private static let minimumWindowSide: CGFloat = 40

    /// Creates a resolver; it holds no state.
    public init() {
        // Stateless by design — see the type-level comment.
    }

    /// Resolves the front/target pair at `point`.
    ///
    /// `windows` must already be z-ordered front→back, which is exactly what
    /// `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` returns.
    public func resolve(at point: CGPoint, windows: [WindowInfo]) -> Resolution {
        var front: WindowInfo?
        for window in windows where isEligible(window) && window.frame.contains(point) {
            guard let resolvedFront = front else {
                front = window
                continue
            }
            return .peek(PeekTarget(front: resolvedFront, target: window))
        }
        guard let front else {
            return .nothing
        }
        return .frontOnly(front)
    }

    /// The filter rules of requirements §2.1: normal layer, visible, not
    /// tiny, and never Spyglass's own surfaces.
    private func isEligible(_ window: WindowInfo) -> Bool {
        window.layer == 0
            && window.alpha > 0
            && window.frame.width >= Self.minimumWindowSide
            && window.frame.height >= Self.minimumWindowSide
            && !window.isOwnWindow
    }
}
