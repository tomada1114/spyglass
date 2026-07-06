import AppKit
import Observation
import SpyglassCore
import SwiftUI

/// Overlay layout constants (`docs/design.md` §4).
private enum Overlay {
    /// Caption pill height (24) + its 8 pt gap below the circle.
    static let captionArea: CGFloat = 32
    static let dismissSeconds: TimeInterval = 0.12
    static let flashSeconds: TimeInterval = 0.25
    static let flashRimWidth: CGFloat = 2
    /// Diameter → radius divisor.
    static let radiusDivisor: CGFloat = 2
}

/// Presentation phase driving the overlay's appear/dismiss/flash motion.
private enum OverlayPhase {
    case dismissing
    case flashing
    case hidden
    case shown
}

/// State the coordinator mutates and the hosted SwiftUI root renders.
@MainActor
@Observable
private final class OverlayModel {
    var diameter: CGFloat = 320
    var content: LensContent = .empty
    var caption: LensCaption?
    var phase: OverlayPhase = .hidden
}

/// The panel's SwiftUI root: the lens plus phase-driven motion and the
/// click-to-raise brass flash ring.
private struct LensRootView: View {
    let model: OverlayModel

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        LensView(diameter: model.diameter, content: model.content, caption: model.caption)
            .overlay(alignment: .top) {
                flashRing
            }
            .scaleEffect(reduceMotion ? 1 : scale, anchor: .center)
            .opacity(model.phase == .hidden || model.phase == .dismissing ? 0 : 1)
            .animation(animation, value: model.phase)
            .frame(
                width: model.diameter,
                height: model.diameter + Overlay.captionArea,
                alignment: .top,
            )
    }

    private var scale: CGFloat {
        switch model.phase {
        case .hidden:
            LensMotion.appearScale

        case .shown:
            1

        case .dismissing:
            LensMotion.dismissScale

        case .flashing:
            LensMotion.clickScale
        }
    }

    private var animation: Animation {
        switch model.phase {
        case .hidden, .shown:
            LensMotion.appear

        case .dismissing:
            LensMotion.dismiss

        case .flashing:
            LensMotion.clickFlash
        }
    }

    /// Rim + specular arc flash to brassBright during click-to-raise
    /// (design §4: "rim & highlight animate to brassBright"). The arc reuses
    /// LensView's specular geometry so the caught light brightens in place.
    /// Reduce Motion keeps the flash, drops the scale pulse — wireframes §6.2.
    @ViewBuilder private var flashRing: some View {
        if model.phase == .flashing {
            ZStack {
                Circle()
                    .strokeBorder(Color.brassBright, lineWidth: Overlay.flashRimWidth)
                Circle()
                    .trim(
                        from: LensMetrics.specularStartDegrees / LensMetrics.fullTurnDegrees,
                        to: LensMetrics.specularEndDegrees / LensMetrics.fullTurnDegrees,
                    )
                    .stroke(Color.brassBright, lineWidth: LensMetrics.specularWidth)
                    .blur(radius: LensMetrics.specularBlur)
            }
            .frame(width: model.diameter, height: model.diameter)
            .transition(.opacity)
        }
    }
}

/// Borderless click-catching panel; `mouseDown` is the only event it wants.
private final class LensPanel: NSPanel {
    var onLeftClick: ((NSPoint) -> Void)?

    override var canBecomeKey: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        onLeftClick?(event.locationInWindow)
    }
}

/// Owns the lens overlay `NSPanel`: non-activating, all-Spaces, above
/// everything, moving with the cursor with zero animation.
@MainActor
final class LensOverlayController {
    /// Fired when a left click lands inside the lens circle.
    var onClickInsideLens: (() -> Void)?

    private let model = OverlayModel()
    private var panel: LensPanel?
    private var hideWorkItem: DispatchWorkItem?

    /// Shows the lens (empty state) with its top-left at `lensRect`
    /// (AppKit coordinates, already clamped by `LensGeometry`).
    func show(lensRect: CGRect, diameter: CGFloat) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        model.diameter = diameter
        model.content = .empty
        model.caption = nil
        let host = panel ?? makePanel()
        panel = host
        host.setFrame(panelFrame(for: lensRect), display: false)
        host.orderFrontRegardless()
        model.phase = .shown
    }

    /// Follows the cursor — direct frame set, never animated (design §4).
    func move(lensRect: CGRect) {
        panel?.setFrameOrigin(panelFrame(for: lensRect).origin)
    }

    /// Swaps what the lens shows.
    func update(content: LensContent, caption: LensCaption?) {
        model.content = content
        model.caption = caption
    }

    /// Fades out (≤ 120 ms) and orders the panel out.
    func hide() {
        guard model.phase == .shown || model.phase == .flashing else {
            return
        }
        model.phase = .dismissing
        scheduleOrderOut(after: Overlay.dismissSeconds)
    }

    /// Click feedback: flash + scale, then dismiss; ≤ 250 ms total.
    func flashAndHide() {
        model.phase = .flashing
        scheduleOrderOut(after: Overlay.flashSeconds)
    }

    private func scheduleOrderOut(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            model.phase = .hidden
            panel?.orderOut(nil)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Panel = lens circle + caption strip below it.
    private func panelFrame(for lensRect: CGRect) -> CGRect {
        CGRect(
            x: lensRect.minX,
            y: lensRect.minY - Overlay.captionArea,
            width: lensRect.width,
            height: lensRect.height + Overlay.captionArea,
        )
    }

    private func makePanel() -> LensPanel {
        let host = LensPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        host.level = .screenSaver
        host.isOpaque = false
        host.backgroundColor = .clear
        host.hasShadow = false
        host.collectionBehavior = [.canJoinAllSpaces, .transient]
        host.ignoresMouseEvents = false
        host.isReleasedWhenClosed = false
        host.contentView = NSHostingView(rootView: LensRootView(model: model))
        host.onLeftClick = { [weak self] location in
            self?.handleClick(at: location)
        }
        return host
    }

    /// The panel frame is square-plus-caption; only clicks inside the
    /// circle raise the target.
    private func handleClick(at location: NSPoint) {
        let radius = model.diameter / Overlay.radiusDivisor
        let center = NSPoint(x: radius, y: Overlay.captionArea + radius)
        let distance = hypot(location.x - center.x, location.y - center.y)
        if distance <= radius {
            onClickInsideLens?()
        }
    }
}
