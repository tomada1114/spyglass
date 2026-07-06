import AppKit
import SwiftUI

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
        HStack(spacing: LensMetrics.captionInnerSpacing) {
            if let icon = caption.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: LensMetrics.captionIconSize, height: LensMetrics.captionIconSize)
                    .accessibilityHidden(true)
            }
            Text(caption.title)
                .font(.system(size: LensMetrics.captionFontSize, weight: .medium))
                .truncationMode(.middle)
                .lineLimit(1)
        }
        .padding(.horizontal, LensMetrics.captionHorizontalPadding)
        .frame(height: LensMetrics.captionHeight)
        // Background before the width cap so the capsule hugs short titles;
        // the outer frame only limits the proposal (→ middle truncation).
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: LensMetrics.captionMaxWidth)
        .opacity(visible ? 1 : 0)
        .onAppear {
            let fade = Animation
                .easeOut(duration: LensMetrics.captionFadeDuration)
                .delay(LensMetrics.captionFadeDelay)
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
        VStack(spacing: LensMetrics.captionSpacing) {
            lensCircle
            if let caption {
                CaptionPill(caption: caption)
            }
        }
        .accessibilityHidden(true)
    }

    private var contentDiameter: CGFloat {
        diameter - LensMetrics.contentInset
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
                // Target swap: cross-fade through the empty state (design §4).
                .animation(LensMotion.swapFade, value: content.kind)
            vignette
            innerGlassEdge
            rim
            specularHighlight
        }
        .frame(width: diameter, height: diameter)
        .compositingGroup()
        .shadow(
            color: .black.opacity(
                colorScheme == .dark
                    ? LensMetrics.shadowOpacityDark
                    : LensMetrics.shadowOpacityLight,
            ),
            radius: LensMetrics.shadowRadius,
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
                    .font(.system(size: LensMetrics.placeholderGlyphSize))
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
                .font(.system(size: LensMetrics.emptySymbolSize))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .opacity(LensMetrics.emptySymbolOpacity)
                .accessibilityHidden(true)
        }
    }

    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: LensMetrics.vignetteClearRadius),
                .init(color: .black.opacity(LensMetrics.vignetteEdgeOpacity), location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: contentDiameter / LensMetrics.radiusDivisor,
        )
        .frame(width: contentDiameter, height: contentDiameter)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    /// The masked-hairline glass edge: a uniform ring reads as a fake
    /// border, so the stroke is faded by a 135° gradient instead.
    private var innerGlassEdge: some View {
        Circle()
            .strokeBorder(Color.white, lineWidth: LensMetrics.innerEdgeWidth)
            .frame(width: contentDiameter, height: contentDiameter)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(LensMetrics.innerEdgeTopOpacity), location: 0),
                        .init(color: .clear, location: LensMetrics.rimMidStop),
                        .init(
                            color: .white.opacity(LensMetrics.innerEdgeBottomOpacity),
                            location: 1,
                        ),
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
                        .init(color: .brassMid, location: LensMetrics.rimMidStop),
                        .init(color: .brassDeep, location: 1),
                    ],
                    startPoint: lightSweep.start,
                    endPoint: lightSweep.end,
                ),
                lineWidth: LensMetrics.rimWidth,
            )
            .frame(width: diameter, height: diameter)
    }

    /// The "˚" glint: an arc in the upper-left, blurred so it reads as
    /// caught light rather than a stroke.
    private var specularHighlight: some View {
        Circle()
            .trim(
                from: LensMetrics.specularStartDegrees / LensMetrics.fullTurnDegrees,
                to: LensMetrics.specularEndDegrees / LensMetrics.fullTurnDegrees,
            )
            .stroke(
                Color.white.opacity(LensMetrics.specularOpacity),
                lineWidth: LensMetrics.specularWidth,
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: LensMetrics.specularBlur)
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
