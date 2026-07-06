import AppKit
import SpyglassCore

/// Snapshots the on-screen window list for `WindowResolver`.
///
/// `CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` returns windows
/// already ordered front→back — the resolver relies on that order.
@MainActor
struct WindowEnumerator {
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// The current snapshot, frames in CG global (top-left origin) space.
    func snapshot() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]]
        else {
            return []
        }
        return list.compactMap(windowInfo(from:))
    }

    private func windowInfo(from entry: [String: Any]) -> WindowInfo? {
        guard
            let number = entry[kCGWindowNumber as String] as? UInt32,
            let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
            let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
            let layer = entry[kCGWindowLayer as String] as? Int,
            let ownerPID = entry[kCGWindowOwnerPID as String] as? Int32
        else {
            return nil
        }
        return WindowInfo(
            id: number,
            frame: frame,
            layer: layer,
            alpha: entry[kCGWindowAlpha as String] as? Double ?? 1,
            ownerPID: ownerPID,
            title: entry[kCGWindowName as String] as? String,
            appName: entry[kCGWindowOwnerName as String] as? String,
            isOwnWindow: ownerPID == ownPID,
        )
    }
}
