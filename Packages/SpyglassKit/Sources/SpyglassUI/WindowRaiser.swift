import AppKit
import ApplicationServices
import os
import SpyglassCore

/// Raises and activates the peeked window (click-to-raise).
///
/// There is no public bridge from a CG window number to an AX element, so
/// the target is matched by frame among the owning app's AX windows — the
/// same heuristic the raise-utilities ecosystem uses. AX positions share
/// CG's top-left-origin global space, so `WindowInfo.frame` compares
/// directly.
@MainActor
struct WindowRaiser {
    /// AX frames can disagree with the CG snapshot by a point or two.
    private static let matchTolerance: CGFloat = 4

    private static let logger = Logger(
        subsystem: "io.github.tomada1114.Spyglass",
        category: "raise",
    )

    /// Activates the owning app and raises the matched window. Failure is
    /// silent-safe by spec: activation alone still brings the app forward.
    func raise(_ window: WindowInfo) {
        NSRunningApplication(processIdentifier: window.ownerPID)?.activate()
        guard let axWindow = matchAXWindow(for: window) else {
            Self.logger.notice("no AX window matched; activated app only")
            return
        }
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }

    private func matchAXWindow(for window: WindowInfo) -> AXUIElement? {
        let app = AXUIElementCreateApplication(window.ownerPID)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            app,
            kAXWindowsAttribute as CFString,
            &value,
        )
        guard result == .success, let windows = value as? [AXUIElement] else {
            return nil
        }
        return windows.first { candidate in
            guard let frame = frame(of: candidate) else {
                return false
            }
            return isClose(frame, to: window.frame)
        }
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = copyAXValue(element, attribute: kAXPositionAttribute),
            let sizeValue = copyAXValue(element, attribute: kAXSizeAttribute)
        else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue, .cgPoint, &position),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func copyAXValue(_ element: AXUIElement, attribute: String) -> AXValue? {
        var raw: CFTypeRef?
        let copied = AXUIElementCopyAttributeValue(element, attribute as CFString, &raw)
        guard copied == .success, let raw, CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        // The type ID was just verified; CF offers no checked cast here (the
        // compiler rejects `as?` to CF types as always-succeeding).
        return unsafeDowncast(raw, to: AXValue.self)
    }

    private func isClose(_ lhs: CGRect, to rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= Self.matchTolerance
            && abs(lhs.minY - rhs.minY) <= Self.matchTolerance
            && abs(lhs.width - rhs.width) <= Self.matchTolerance
            && abs(lhs.height - rhs.height) <= Self.matchTolerance
    }
}
