import AppKit
import SpyglassCore

/// The conductor: feeds events into Core's `PeekStateMachine` and executes
/// the effects it returns against the overlay, capture engine, and raiser.
/// All decisions live in Core; this type only translates.
@MainActor
public final class PeekCoordinator {
    private enum Timing {
        /// Hold threshold before the lens appears (requirements §2.1).
        static let holdSeconds: TimeInterval = 0.15
        /// Stream-swap debounce on target change (requirements §2.1).
        static let debounceSeconds: TimeInterval = 0.08
    }

    /// Inset from lens rect to the content circle (design §4: D − 4).
    private static let contentInset: CGFloat = 2

    /// Invoked when a trigger press finds permissions missing — the app
    /// shows onboarding instead of a lens (wireframes §5.3).
    public var onPermissionProblem: (() -> Void)?

    private let settings: SettingsStore
    private let permissions: PermissionsService
    private let classifier = TriggerKeyClassifier()
    private let resolver = WindowResolver()
    private let enumerator = WindowEnumerator()
    private let eventMonitor = EventMonitor()
    private let capture = CaptureEngine()
    private let overlay = LensOverlayController()
    private let raiser = WindowRaiser()

    private var machine = PeekStateMachine()
    private var holdTimer: DispatchWorkItem?
    private var debounceTimer: DispatchWorkItem?
    private var windowsByID: [WindowID: WindowInfo] = [:]
    private var currentTarget: WindowInfo?
    private var latestImage: CGImage?
    private var sessionDiameter: CGFloat = 0
    private var lensRectAppKit: CGRect = .zero

    private var machineTarget: WindowID? {
        if case let .peeking(target) = machine.state {
            return target
        }
        return nil
    }

    private var mainDisplayHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Wires the coordinator to settings and permission state.
    public init(settings: SettingsStore, permissions: PermissionsService) {
        self.settings = settings
        self.permissions = permissions
    }

    /// Installs the permanent key monitors and connects the pipeline.
    public func start() {
        eventMonitor.onKeyEvent = { [weak self] snapshot in
            self?.handleKey(snapshot)
        }
        eventMonitor.onMouseMoved = { [weak self] location in
            self?.cursorMoved(to: location)
        }
        capture.onFrame = { [weak self] image in
            self?.latestImage = image
            self?.pushContent()
        }
        capture.onStopped = { [weak self] in
            self?.streamDied()
        }
        overlay.onClickInsideLens = { [weak self] in
            guard let self else {
                return
            }
            perform(machine.handle(.clickedInsideLens))
        }
        eventMonitor.startKeyMonitoring()
    }

    // MARK: - Inputs

    private func handleKey(_ snapshot: KeyEventSnapshot) {
        switch classifier.classify(snapshot, trigger: settings.triggerKey) {
        case .engaged:
            guard permissions.model.menuBarState == .normal else {
                onPermissionProblem?()
                return
            }
            perform(machine.handle(.triggerEngaged))

        case .released:
            perform(machine.handle(.triggerReleased))

        case .cancelled:
            perform(machine.handle(.otherKeyPressed))

        case .irrelevant:
            break
        }
    }

    private func cursorMoved(to location: CGPoint) {
        guard case .peeking = machine.state else {
            return
        }
        lensRectAppKit = lensRect(around: location)
        overlay.move(lensRect: lensRectAppKit)
        pushContent()
        resolveTarget()
    }

    // MARK: - Effects

    private func perform(_ effects: [PeekStateMachine.Effect]) {
        let raising = effects.contains { effect in
            if case .raiseTarget = effect {
                return true
            }
            return false
        }
        for effect in effects {
            apply(effect, raising: raising)
        }
    }

    private func apply(_ effect: PeekStateMachine.Effect, raising: Bool) {
        switch effect {
        case .startHoldTimer:
            scheduleHoldTimer()

        case .cancelHoldTimer:
            holdTimer?.cancel()
            holdTimer = nil

        case .showLens:
            beginPeek()

        case .hideLens:
            endPeek(raising: raising)

        case let .startStream(id):
            beginStream(id)

        case .stopStream:
            capture.stop()
            latestImage = nil
            currentTarget = nil
            overlay.update(content: .empty, caption: nil)

        case let .raiseTarget(id):
            if let target = windowsByID[id] {
                raiser.raise(target)
            }
        }
    }

    private func scheduleHoldTimer() {
        holdTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            perform(machine.handle(.holdTimerFired))
        }
        holdTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.holdSeconds, execute: work)
    }

    private func beginPeek() {
        sessionDiameter = settings.lensDiameter
        lensRectAppKit = lensRect(around: NSEvent.mouseLocation)
        overlay.show(lensRect: lensRectAppKit, diameter: sessionDiameter)
        eventMonitor.startMouseMonitoring()
        resolveTarget()
    }

    private func endPeek(raising: Bool) {
        eventMonitor.stopMouseMonitoring()
        debounceTimer?.cancel()
        debounceTimer = nil
        if raising {
            overlay.flashAndHide()
        } else {
            overlay.hide()
        }
    }

    private func beginStream(_ id: WindowID) {
        latestImage = nil
        currentTarget = windowsByID[id]
        Task {
            await capture.start(windowID: id)
        }
    }

    // MARK: - Resolution

    /// Resolves the window beneath the cursor; target changes are debounced
    /// 80 ms so a cursor sweeping across boundaries doesn't thrash streams.
    private func resolveTarget() {
        let windows = enumerator.snapshot()
        windowsByID = Dictionary(windows.map { ($0.id, $0) }) { first, _ in first }
        let cursorCG = LensGeometry.appKitToCG(
            point: NSEvent.mouseLocation,
            mainDisplayHeight: mainDisplayHeight,
        )
        let resolved: WindowID? = switch resolver.resolve(at: cursorCG, windows: windows) {
        case let .peek(pair):
            pair.target.id

        case .frontOnly, .nothing:
            nil
        }
        guard resolved != machineTarget else {
            return
        }
        guard machineTarget != nil else {
            feedTarget(resolved)
            return
        }
        debounceTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.feedTarget(resolved)
        }
        debounceTimer = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Timing.debounceSeconds,
            execute: work,
        )
    }

    private func feedTarget(_ id: WindowID?) {
        perform(machine.handle(.targetResolved(id)))
    }

    // MARK: - Rendering

    /// Ships the latest frame with a crop recomputed for the current lens
    /// position, so the hole illusion tracks the cursor between frames.
    private func pushContent() {
        guard let target = currentTarget, let image = latestImage else {
            return
        }
        let lensRectCG = LensGeometry.appKitToCG(
            rect: lensRectAppKit,
            mainDisplayHeight: mainDisplayHeight,
        )
        let contentRectCG = lensRectCG.insetBy(dx: Self.contentInset, dy: Self.contentInset)
        let crop = LensGeometry.captureCrop(
            lensRectInScreen: contentRectCG,
            windowFrameInScreen: target.frame,
        )
        let frame = LensFrame(
            image: image,
            imageSize: target.frame.size,
            cropOrigin: crop.origin,
        )
        overlay.update(content: .frame(frame), caption: caption(for: target))
    }

    private func caption(for target: WindowInfo) -> LensCaption {
        LensCaption(
            appIcon: NSRunningApplication(processIdentifier: target.ownerPID)?.icon,
            title: target.title ?? target.appName ?? "Window",
        )
    }

    // MARK: - Failures

    /// Stream death is silent-safe: empty lens, retry on next target
    /// change — unless a permission was revoked, which ends the session.
    private func streamDied() {
        permissions.refresh()
        guard permissions.model.menuBarState == .normal else {
            perform(machine.handle(.permissionLost))
            return
        }
        latestImage = nil
        currentTarget = nil
        feedTarget(nil)
    }

    // MARK: - Geometry

    private func lensRect(around cursor: CGPoint) -> CGRect {
        let screen = NSScreen.screens.first { candidate in
            NSMouseInRect(cursor, candidate.frame, false)
        } ?? NSScreen.main
        let bounds = screen?.frame ?? .zero
        return LensGeometry.lensRect(
            center: cursor,
            diameter: sessionDiameter,
            screenBounds: bounds,
        )
    }
}
