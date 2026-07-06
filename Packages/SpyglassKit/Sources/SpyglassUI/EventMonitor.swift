import AppKit
import SpyglassCore

/// Global + local NSEvent monitors feeding Core's classifier.
///
/// Global monitors never see the app's own events, so a local twin runs the
/// same handler (research-verified requirement). Key monitors live for the
/// app's lifetime; the mouse monitor exists only while peeking so idle CPU
/// stays at zero.
@MainActor
final class EventMonitor {
    /// Fired for every flagsChanged/keyDown, already flattened for Core.
    var onKeyEvent: ((KeyEventSnapshot) -> Void)?
    /// Fired per mouse move with the AppKit-global cursor position.
    var onMouseMoved: ((CGPoint) -> Void)?

    private var keyMonitors: [Any] = []
    private var mouseMonitors: [Any] = []

    /// Installs the permanent key monitors (needs Accessibility).
    func startKeyMonitoring() {
        guard keyMonitors.isEmpty else {
            return
        }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: mask,
            handler: { [weak self] event in
                let snapshot = snapshot(of: event)
                deliver(to: self) { $0.onKeyEvent?(snapshot) }
            },
        ) {
            keyMonitors.append(global)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let snapshot = snapshot(of: event)
            deliver(to: self) { $0.onKeyEvent?(snapshot) }
            return event
        }
        if let local {
            keyMonitors.append(local)
        }
    }

    /// Installs mouse-move monitors for the duration of a peek.
    func startMouseMonitoring() {
        guard mouseMonitors.isEmpty else {
            return
        }
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved,
            handler: { [weak self] _ in
                deliver(to: self) { $0.onMouseMoved?(NSEvent.mouseLocation) }
            },
        ) {
            mouseMonitors.append(global)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            deliver(to: self) { $0.onMouseMoved?(NSEvent.mouseLocation) }
            return event
        }
        if let local {
            mouseMonitors.append(local)
        }
    }

    /// Removes the mouse monitors when the peek ends.
    func stopMouseMonitoring() {
        for monitor in mouseMonitors {
            NSEvent.removeMonitor(monitor)
        }
        mouseMonitors = []
    }
}

/// Monitor handlers arrive on the main thread in practice but carry no
/// isolation in the SDK signature; this hops safely either way without
/// adding latency on the main-thread path.
private func deliver(
    to monitor: EventMonitor?,
    _ body: @escaping @MainActor (EventMonitor) -> Void,
) {
    guard let monitor else {
        return
    }
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            body(monitor)
        }
    } else {
        Task { @MainActor in
            body(monitor)
        }
    }
}

/// Flattens an NSEvent into Core's platform-neutral snapshot.
private func snapshot(of event: NSEvent) -> KeyEventSnapshot {
    KeyEventSnapshot(
        keyCode: event.keyCode,
        isFlagsChanged: event.type == .flagsChanged,
        isKeyDown: event.type == .keyDown,
        rawModifierFlags: UInt64(event.modifierFlags.rawValue),
    )
}
