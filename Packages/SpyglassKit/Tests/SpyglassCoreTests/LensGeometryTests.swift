import CoreGraphics
import SpyglassCore
import Testing

@Suite("LensGeometry")
struct LensGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
    private let diameter: CGFloat = 320

    // MARK: - Lens rect

    @Test
    func `lens is centered on the cursor when fully on screen`() {
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: 400, y: 300),
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect == CGRect(x: 240, y: 140, width: 320, height: 320))
    }

    @Test
    func `lens slides against the left edge instead of clipping`() {
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: 10, y: 300),
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect.minX == 0)
        #expect(rect.midY == 300)
    }

    @Test
    func `lens slides against the right edge instead of clipping`() {
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: 795, y: 300),
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect.maxX == 800)
    }

    @Test
    func `lens slides against the top edge instead of clipping`() {
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: 400, y: 5),
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect.minY == 0)
    }

    @Test
    func `lens slides against the bottom edge instead of clipping`() {
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: 400, y: 598),
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect.maxY == 600)
    }

    @Test
    func `corner clamping slides on both axes at once`() {
        let rect = LensGeometry.lensRect(
            center: .zero,
            diameter: diameter,
            screenBounds: screen,
        )
        #expect(rect.origin == .zero)
    }

    @Test
    func `clamping respects a screen not anchored at the global origin`() {
        let secondary = CGRect(x: -960, y: -540, width: 960, height: 540)
        let rect = LensGeometry.lensRect(
            center: CGPoint(x: -955, y: -535),
            diameter: diameter,
            screenBounds: secondary,
        )
        #expect(rect.origin == CGPoint(x: -960, y: -540))
    }

    // MARK: - Capture crop

    @Test
    func `capture crop translates the lens rect into window-local coordinates`() {
        let crop = LensGeometry.captureCrop(
            lensRectInScreen: CGRect(x: 100, y: 200, width: 320, height: 320),
            windowFrameInScreen: CGRect(x: 50, y: 150, width: 800, height: 600),
        )
        #expect(crop == CGRect(x: 50, y: 50, width: 320, height: 320))
    }

    @Test
    func `capture crop can extend past the window bounds when the lens overhangs`() {
        let crop = LensGeometry.captureCrop(
            lensRectInScreen: CGRect(x: 0, y: 0, width: 320, height: 320),
            windowFrameInScreen: CGRect(x: 100, y: 100, width: 800, height: 600),
        )
        #expect(crop.origin == CGPoint(x: -100, y: -100))
    }

    // MARK: - Coordinate flipping

    @Test
    func `cg to appkit point flips y against the main display height`() {
        let flipped = LensGeometry.cgToAppKit(
            point: CGPoint(x: 100, y: 200),
            mainDisplayHeight: 600,
        )
        #expect(flipped == CGPoint(x: 100, y: 400))
    }

    @Test(arguments: [
        CGPoint(x: 100, y: 200),
        CGPoint(x: -500, y: 300),
        CGPoint(x: 250, y: -400),
    ])
    func `point conversion round-trips on main and secondary displays`(point: CGPoint) {
        let there = LensGeometry.cgToAppKit(point: point, mainDisplayHeight: 600)
        let back = LensGeometry.appKitToCG(point: there, mainDisplayHeight: 600)
        #expect(back == point)
    }

    @Test
    func `cg to appkit rect flips around the rect's own height`() {
        let flipped = LensGeometry.cgToAppKit(
            rect: CGRect(x: 0, y: 0, width: 100, height: 50),
            mainDisplayHeight: 600,
        )
        #expect(flipped == CGRect(x: 0, y: 550, width: 100, height: 50))
    }

    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 100, height: 50),
        CGRect(x: -960, y: -540, width: 960, height: 540),
        CGRect(x: 300, y: 900, width: 320, height: 320),
    ])
    func `rect conversion round-trips on main and secondary displays`(rect: CGRect) {
        let there = LensGeometry.cgToAppKit(rect: rect, mainDisplayHeight: 600)
        let back = LensGeometry.appKitToCG(rect: there, mainDisplayHeight: 600)
        #expect(back == rect)
    }
}
