import AppKit
import SwiftUI

/// One captured window frame plus where the lens circle sits inside it.
public struct LensFrame {
    /// The latest frame ScreenCaptureKit delivered for the target window.
    public let image: CGImage
    /// The frame's size in points (the target window's size).
    public let imageSize: CGSize
    /// Top-left of the lens circle in window-local points — computed by
    /// `LensGeometry.captureCrop` so the visible region matches screen
    /// coordinates 1:1 (the hole illusion).
    public let cropOrigin: CGPoint

    /// Bundles one frame for rendering; the overlay is the only producer.
    public init(image: CGImage, imageSize: CGSize, cropOrigin: CGPoint) {
        self.image = image
        self.imageSize = imageSize
        self.cropOrigin = cropOrigin
    }
}

/// What fills the lens circle (`docs/design.md` §4).
public enum LensContent {
    /// State B: frosted material + dashed-circle symbol.
    case empty
    /// State A: a live capture frame, screen-aligned.
    case frame(LensFrame)
    /// The settings live preview: stage fill + brass chart glyph.
    case settingsPlaceholder
    /// Chrome only — the onboarding demo draws its own reveal underneath.
    case transparent
}

/// The identity line under the lens: target app icon + window title.
public struct LensCaption: Equatable {
    /// The target app's icon, rendered at 14 pt.
    public let appIcon: NSImage?
    /// The target window's title, middle-truncated.
    public let title: String

    /// Groups the pill's two data points.
    public init(appIcon: NSImage?, title: String) {
        self.appIcon = appIcon
        self.title = title
    }
}

/// Motion tokens from `docs/design.md` §4 — owned here so the overlay and
/// any preview animate identically. Reduce Motion drops every scale change
/// but keeps these durations (opacity-only).
public enum LensMotion {
    private static let appearResponse = 0.28
    private static let appearDamping = 0.78
    private static let dismissDuration = 0.12
    private static let swapDuration = 0.1
    private static let clickResponse = 0.18
    private static let clickDamping = 0.7

    /// Appear: spring, anchored at the cursor.
    public static let appear = Animation.spring(
        response: appearResponse,
        dampingFraction: appearDamping,
    )
    /// Scale the lens appears from.
    public static let appearScale: CGFloat = 0.86
    /// Dismiss on key-up: ≤ 120 ms fade.
    public static let dismiss = Animation.easeOut(duration: dismissDuration)
    /// Scale the lens dismisses toward.
    public static let dismissScale: CGFloat = 0.94
    /// Target swap: content cross-fades through empty, 100 ms each way.
    public static let swapFade = Animation.easeInOut(duration: swapDuration)
    /// Click-to-raise flash spring; total feedback stays ≤ 250 ms.
    public static let clickFlash = Animation.spring(
        response: clickResponse,
        dampingFraction: clickDamping,
    )
    /// Scale pulse peak during the click flash.
    public static let clickScale: CGFloat = 1.06
}

/// Every fixed number in `docs/design.md` §4, named so deviations from the
/// spec are diffable (and for the no-magic-numbers gate).
private enum Metrics {
    /// The content circle is rim diameter − 4.
    static let contentInset: CGFloat = 4
    /// Diameter → radius divisor.
    static let radiusDivisor: CGFloat = 2
    static let vignetteClearRadius: CGFloat = 0.78
    static let vignetteEdgeOpacity = 0.08
    static let innerEdgeWidth: CGFloat = 1
    static let innerEdgeTopOpacity = 0.4
    static let innerEdgeBottomOpacity = 0.15
    static let rimWidth: CGFloat = 2
    static let rimMidStop: CGFloat = 0.55
    static let specularStartDegrees: CGFloat = 190
    static let specularEndDegrees: CGFloat = 240
    static let fullTurnDegrees: CGFloat = 360
    static let specularWidth: CGFloat = 3
    static let specularOpacity = 0.6
    static let specularBlur: CGFloat = 4
    static let shadowOpacityLight = 0.2
    static let shadowOpacityDark = 0.28
    static let shadowRadius: CGFloat = 12
    static let captionSpacing: CGFloat = 8
    static let captionInnerSpacing: CGFloat = 4
    static let captionHeight: CGFloat = 24
    static let captionHorizontalPadding: CGFloat = 10
    static let captionIconSize: CGFloat = 14
    static let captionFontSize: CGFloat = 13
    static let captionMaxWidth: CGFloat = 260
    static let captionFadeDelay: TimeInterval = 0.08
    static let captionFadeDuration: TimeInterval = 0.1
    static let emptySymbolSize: CGFloat = 28
    static let emptySymbolOpacity = 0.4
    static let placeholderGlyphSize: CGFloat = 20
}

/// Preview-only sizing.
private enum PreviewMetrics {
    static let diameter: CGFloat = 320
    static let padding: CGFloat = 64
}

/// The caption pill (State A only), staggered so the lens always leads.
private struct CaptionPill: View {
    let caption: LensCaption

    @State private var visible = false

    var body: some View {
        HStack(spacing: Metrics.captionInnerSpacing) {
            if let icon = caption.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Metrics.captionIconSize, height: Metrics.captionIconSize)
                    .accessibilityHidden(true)
            }
            Text(caption.title)
                .font(.system(size: Metrics.captionFontSize, weight: .medium))
                .truncationMode(.middle)
                .lineLimit(1)
        }
        .padding(.horizontal, Metrics.captionHorizontalPadding)
        .frame(height: Metrics.captionHeight)
        .frame(maxWidth: Metrics.captionMaxWidth)
        .fixedSize()
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(visible ? 1 : 0)
        .onAppear {
            let fade = Animation
                .easeOut(duration: Metrics.captionFadeDuration)
                .delay(Metrics.captionFadeDelay)
            withAnimation(fade) {
                visible = true
            }
        }
    }
}

/// The hero component (`docs/design.md` §4): six layers, back to front —
/// content, vignette, inner glass edge, brass rim, specular highlight,
/// omnidirectional shadow. Used full-size by the overlay, at ¼ scale by the
/// settings preview, and at 64 pt inside the onboarding demo.
///
/// The whole view is `accessibilityHidden` — the lens is decorative;
/// VoiceOver users interact with the real windows directly.
public struct LensView: View {
    let diameter: CGFloat
    let content: LensContent
    let caption: LensCaption?

    @Environment(\.colorScheme)
    private var colorScheme
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    public var body: some View {
        VStack(spacing: Metrics.captionSpacing) {
            lensCircle
            if let caption {
                CaptionPill(caption: caption)
            }
        }
        .accessibilityHidden(true)
    }

    private var contentDiameter: CGFloat {
        diameter - Metrics.contentInset
    }

    /// 135° in the spec: top-left toward bottom-right, the app's single
    /// light direction.
    private var lightSweep: (start: UnitPoint, end: UnitPoint) {
        (.topLeading, .bottomTrailing)
    }

    private var lensCircle: some View {
        ZStack {
            contentLayer
                .frame(width: contentDiameter, height: contentDiameter)
                .clipShape(Circle())
            vignette
            innerGlassEdge
            rim
            specularHighlight
        }
        .frame(width: diameter, height: diameter)
        .compositingGroup()
        .shadow(
            color: .black.opacity(
                colorScheme == .dark ? Metrics.shadowOpacityDark : Metrics.shadowOpacityLight,
            ),
            radius: Metrics.shadowRadius,
            x: 0,
            y: 0,
        )
    }

    @ViewBuilder private var contentLayer: some View {
        switch content {
        case .empty:
            emptyState

        case let .frame(frame):
            Image(decorative: frame.image, scale: 1)
                .resizable()
                .frame(width: frame.imageSize.width, height: frame.imageSize.height)
                .offset(x: -frame.cropOrigin.x, y: -frame.cropOrigin.y)
                .frame(
                    width: contentDiameter,
                    height: contentDiameter,
                    alignment: .topLeading,
                )

        case .settingsPlaceholder:
            ZStack {
                Color.stageBackground
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: Metrics.placeholderGlyphSize))
                    .foregroundStyle(Color.brassPrimary)
                    .accessibilityHidden(true)
            }

        case .transparent:
            Color.clear
        }
    }

    private var emptyState: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                VisualEffectView(material: .hudWindow)
            }
            Image(systemName: "circle.dashed")
                .font(.system(size: Metrics.emptySymbolSize))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .opacity(Metrics.emptySymbolOpacity)
                .accessibilityHidden(true)
        }
    }

    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: Metrics.vignetteClearRadius),
                .init(color: .black.opacity(Metrics.vignetteEdgeOpacity), location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: contentDiameter / Metrics.radiusDivisor,
        )
        .frame(width: contentDiameter, height: contentDiameter)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    /// The masked-hairline glass edge: a uniform ring reads as a fake
    /// border, so the stroke is faded by a 135° gradient instead.
    private var innerGlassEdge: some View {
        Circle()
            .strokeBorder(Color.white, lineWidth: Metrics.innerEdgeWidth)
            .frame(width: contentDiameter, height: contentDiameter)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(Metrics.innerEdgeTopOpacity), location: 0),
                        .init(color: .clear, location: Metrics.rimMidStop),
                        .init(color: .white.opacity(Metrics.innerEdgeBottomOpacity), location: 1),
                    ],
                    startPoint: lightSweep.start,
                    endPoint: lightSweep.end,
                ),
            )
    }

    private var rim: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .brassBright, location: 0),
                        .init(color: .brassMid, location: Metrics.rimMidStop),
                        .init(color: .brassDeep, location: 1),
                    ],
                    startPoint: lightSweep.start,
                    endPoint: lightSweep.end,
                ),
                lineWidth: Metrics.rimWidth,
            )
            .frame(width: diameter, height: diameter)
    }

    /// The "˚" glint: an arc in the upper-left, blurred so it reads as
    /// caught light rather than a stroke.
    private var specularHighlight: some View {
        Circle()
            .trim(
                from: Metrics.specularStartDegrees / Metrics.fullTurnDegrees,
                to: Metrics.specularEndDegrees / Metrics.fullTurnDegrees,
            )
            .stroke(
                Color.white.opacity(Metrics.specularOpacity),
                lineWidth: Metrics.specularWidth,
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: Metrics.specularBlur)
    }

    /// Creates a lens; `caption` is nil in every state but a streaming peek.
    public init(diameter: CGFloat, content: LensContent, caption: LensCaption? = nil) {
        self.diameter = diameter
        self.content = content
        self.caption = caption
    }
}

#Preview("Normal (placeholder content) + caption") {
    LensView(
        diameter: PreviewMetrics.diameter,
        content: .settingsPlaceholder,
        caption: LensCaption(appIcon: NSApp?.applicationIconImage, title: "Quarterly Report"),
    )
    .padding(PreviewMetrics.padding)
}

#Preview("Empty state") {
    LensView(diameter: PreviewMetrics.diameter, content: .empty)
        .padding(PreviewMetrics.padding)
}
