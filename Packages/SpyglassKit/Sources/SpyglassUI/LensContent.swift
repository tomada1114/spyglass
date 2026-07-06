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
/// spec are diffable (and for the no-magic-numbers gate). Internal because
/// the overlay's click-flash chrome must reuse the exact same geometry.
enum LensMetrics {
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

    /// Case discriminator for the target-swap cross-fade. Frame identity is
    /// deliberately excluded so successive stream frames never animate —
    /// only entering/leaving the empty state does (design §4 motion table).
    enum Kind: Equatable {
        case empty
        case frame
        case settingsPlaceholder
        case transparent
    }

    var kind: Kind {
        switch self {
        case .empty:
            .empty

        case .frame:
            .frame

        case .settingsPlaceholder:
            .settingsPlaceholder

        case .transparent:
            .transparent
        }
    }
}
