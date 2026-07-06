import AppKit
import os

/// Restarts the app — required after an in-session Screen Recording grant,
/// which macOS only applies to a fresh process.
@MainActor
public enum Relauncher {
    private static let logger = Logger(
        subsystem: "io.github.tomada1114.Spyglass",
        category: "relauncher",
    )

    /// Spawns `open -n` on our own bundle, then terminates. `-n` forces a
    /// new instance so launch services cannot just reactivate this one.
    public static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try process.run()
        } catch {
            // Nothing sane to show mid-relaunch; staying alive beats dying.
            logger.error("relaunch failed: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }
}
