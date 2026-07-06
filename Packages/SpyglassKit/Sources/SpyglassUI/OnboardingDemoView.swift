import SwiftUI

/// Every fixed number of the demo stage (`docs/design.md` §7).
private enum Stage {
    static let width: CGFloat = 376
    static let height: CGFloat = 180
    static let cornerRadius: CGFloat = 12
    static let windowCornerRadius: CGFloat = 8
    static let frontWidth: CGFloat = 240
    static let frontHeight: CGFloat = 120
    static let backWidth: CGFloat = 200
    static let backHeight: CGFloat = 100
    /// Back window sits (+70, +30) from the front window's center.
    static let backDX: CGFloat = 70
    static let backDY: CGFloat = 30
    /// The front window is nudged up-left so the pair centers on the stage.
    static let frontDX: CGFloat = -35
    static let frontDY: CGFloat = -15
    static let dotDiameter: CGFloat = 6
    static let dotSpacing: CGFloat = 4
    static let dotInset: CGFloat = 10
    static let glyphSize: CGFloat = 28
    static let lensDiameter: CGFloat = 64
    /// The lens circle's content diameter (mirrors LensView's −4 inset).
    static let lensContentDiameter: CGFloat = 60
    /// One sweep of the S-path takes 4 s; autoreverse doubles the cycle.
    static let sweepSeconds: TimeInterval = 4
    /// Horizontal margin the lens keeps inside the front window.
    static let sweepInset: CGFloat = 20
    /// Peak vertical deviation of the S.
    static let sweepAmplitude: CGFloat = 16
    /// Where the lens rests under Reduce Motion: over the overlap, so the
    /// reveal is visible in the still frame.
    static let restingProgress = 0.75
    static let smoothstepScale = 3.0
    static let smoothstepCubic = 2.0
    /// The one arithmetic doubling shared by the sweep math (autoreverse
    /// cycle, both-side insets, half-travel, full sine turn).
    static let two = 2.0
}

/// The looping product demo: a mini lens sweeps an S-path across a mock
/// front window, revealing the mock back window's chart where they overlap.
/// Coded SwiftUI built from the real `LensView` — never a video asset.
struct OnboardingDemoView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            stage(progress: progress(at: context.date))
        }
        .frame(width: Stage.width, height: Stage.height)
        .accessibilityLabel("Demo: a lens revealing a window hidden behind another")
    }

    private var backCenterOffset: CGSize {
        CGSize(
            width: Stage.frontDX + Stage.backDX,
            height: Stage.frontDY + Stage.backDY,
        )
    }

    private var frontWindow: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Stage.windowCornerRadius)
                .fill(Color.stageWindowFront)
            HStack(spacing: Stage.dotSpacing) {
                Circle().fill(Color.trafficRed)
                Circle().fill(Color.trafficYellow)
                Circle().fill(Color.trafficGreen)
            }
            .frame(height: Stage.dotDiameter)
            .padding(Stage.dotInset)
        }
        .frame(width: Stage.frontWidth, height: Stage.frontHeight)
    }

    private var backWindow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Stage.windowCornerRadius)
                .fill(Color.stageWindowBack)
            Image(systemName: "chart.bar.fill")
                .font(.system(size: Stage.glyphSize))
                .foregroundStyle(Color.brassPrimary)
                .accessibilityHidden(true)
        }
        .frame(width: Stage.backWidth, height: Stage.backHeight)
    }

    /// Eased 0→1→0 sweep position; frozen mid-reveal under Reduce Motion.
    private func progress(at date: Date) -> Double {
        guard !reduceMotion else {
            return Stage.restingProgress
        }
        let cycle = Stage.sweepSeconds * Stage.two
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycle) / Stage.sweepSeconds
        let triangle = phase <= 1 ? phase : Stage.two - phase
        // Smoothstep ≈ easeInOut, cheap enough to run per frame.
        return triangle * triangle * (Stage.smoothstepScale - Stage.smoothstepCubic * triangle)
    }

    private func stage(progress: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Stage.cornerRadius)
                .fill(Color.stageBackground)
            backWindow
                .offset(backCenterOffset)
            frontWindow
                .offset(CGSize(width: Stage.frontDX, height: Stage.frontDY))
            backWindow
                .offset(backCenterOffset)
                .mask(revealMask(progress: progress))
            LensView(diameter: Stage.lensDiameter, content: .transparent)
                .offset(lensOffset(progress: progress))
        }
        .frame(width: Stage.width, height: Stage.height)
        .clipShape(RoundedRectangle(cornerRadius: Stage.cornerRadius))
    }

    private func revealMask(progress: Double) -> some View {
        Circle()
            .frame(width: Stage.lensContentDiameter, height: Stage.lensContentDiameter)
            .offset(lensOffset(progress: progress))
    }

    /// The S-path: linear sweep across the front window with a sine bend.
    private func lensOffset(progress: Double) -> CGSize {
        let travel = Stage.frontWidth - Stage.sweepInset * Stage.two
        let xOffset = Stage.frontDX - travel / Stage.two + travel * progress
        let yOffset = Stage.frontDY + Stage.sweepAmplitude * sin(progress * Stage.two * .pi)
        return CGSize(width: xOffset, height: yOffset)
    }
}

#Preview("Demo stage") {
    OnboardingDemoView()
        .padding()
}
