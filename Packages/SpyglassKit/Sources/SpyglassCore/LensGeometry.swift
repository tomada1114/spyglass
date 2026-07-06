import CoreGraphics

/// All lens placement math, and the ONLY place CG↔AppKit coordinate
/// flipping happens.
///
/// CG global space has its origin at the top-left of the main display with y
/// growing down; AppKit uses bottom-left origin with y growing up. The flip
/// is `appKitY = mainDisplayHeight − cgY − height` for rects (and the same
/// formula with height 0 for points), which makes both conversions their own
/// inverse. Call sites must never flip coordinates themselves — that class of
/// bug is confined to this file and its tests.
public enum LensGeometry {
    /// Diameter → radius divisor.
    private static let radiusDivisor: CGFloat = 2

    /// The lens square for a cursor position, slid (never clipped) so it
    /// stays fully inside `screenBounds`.
    ///
    /// All three rects share one coordinate space; the caller picks it.
    public static func lensRect(
        center: CGPoint,
        diameter: CGFloat,
        screenBounds: CGRect,
    ) -> CGRect {
        CGRect(
            x: clamp(
                center.x - diameter / radiusDivisor,
                lower: screenBounds.minX,
                upper: screenBounds.maxX - diameter,
            ),
            y: clamp(
                center.y - diameter / radiusDivisor,
                lower: screenBounds.minY,
                upper: screenBounds.maxY - diameter,
            ),
            width: diameter,
            height: diameter,
        )
    }

    /// Translates the lens rect into the target window's local space — the
    /// region of the captured frame the lens must show for the hole illusion.
    ///
    /// The result may extend past the window's bounds when the lens overhangs
    /// it; the renderer letterboxes that overhang with the empty-state fill.
    public static func captureCrop(
        lensRectInScreen: CGRect,
        windowFrameInScreen: CGRect,
    ) -> CGRect {
        lensRectInScreen.offsetBy(
            dx: -windowFrameInScreen.minX,
            dy: -windowFrameInScreen.minY,
        )
    }

    /// CG global (top-left origin) → AppKit (bottom-left origin).
    public static func cgToAppKit(point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainDisplayHeight - point.y)
    }

    /// AppKit (bottom-left origin) → CG global (top-left origin).
    public static func appKitToCG(point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        cgToAppKit(point: point, mainDisplayHeight: mainDisplayHeight)
    }

    /// CG global → AppKit for a rect; the origin moves to the opposite
    /// vertical edge, so the rect's own height joins the flip.
    public static func cgToAppKit(rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: mainDisplayHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height,
        )
    }

    /// AppKit → CG global for a rect.
    public static func appKitToCG(rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        cgToAppKit(rect: rect, mainDisplayHeight: mainDisplayHeight)
    }

    /// Clamps preferring the lower bound when the range is inverted (lens
    /// wider than the screen), so the lens pins to the leading edge instead
    /// of oscillating.
    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(value, max(lower, upper)))
    }
}
