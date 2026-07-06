import CoreGraphics
import SpyglassCore
import Testing

@Suite("WindowResolver")
struct WindowResolverTests {
    private let resolver = WindowResolver()
    private let point = CGPoint(x: 100, y: 100)

    private func window(
        id: WindowID,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        layer: Int = 0,
        alpha: Double = 1,
        isOwnWindow: Bool = false,
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            frame: frame,
            layer: layer,
            alpha: alpha,
            ownerPID: 42,
            title: "Window \(id)",
            appName: "App \(id)",
            isOwnWindow: isOwnWindow,
        )
    }

    // MARK: - Peek resolution

    @Test
    func `first window under the point is front and the next beneath is target`() {
        let front = window(id: 1)
        let target = window(id: 2)
        let deeper = window(id: 3)
        let resolution = resolver.resolve(at: point, windows: [front, target, deeper])
        #expect(resolution == .peek(PeekTarget(front: front, target: target)))
    }

    @Test
    func `windows not containing the point are ignored for both roles`() {
        let elsewhere = window(id: 1, frame: CGRect(x: 900, y: 900, width: 200, height: 200))
        let front = window(id: 2)
        let target = window(id: 3)
        let resolution = resolver.resolve(at: point, windows: [elsewhere, front, target])
        #expect(resolution == .peek(PeekTarget(front: front, target: target)))
    }

    // MARK: - Filter rules

    @Test
    func `own windows never participate`() {
        let lens = window(id: 1, isOwnWindow: true)
        let front = window(id: 2)
        let resolution = resolver.resolve(at: point, windows: [lens, front])
        #expect(resolution == .frontOnly(front))
    }

    @Test
    func `non-normal layers never participate`() {
        let menuBar = window(id: 1, layer: 25)
        let front = window(id: 2)
        let resolution = resolver.resolve(at: point, windows: [menuBar, front])
        #expect(resolution == .frontOnly(front))
    }

    @Test
    func `fully transparent windows never participate`() {
        let ghost = window(id: 1, alpha: 0)
        let front = window(id: 2)
        let resolution = resolver.resolve(at: point, windows: [ghost, front])
        #expect(resolution == .frontOnly(front))
    }

    @Test(arguments: [
        CGSize(width: 39, height: 600),
        CGSize(width: 800, height: 39),
    ])
    func `windows narrower or shorter than 40pt never participate`(size: CGSize) {
        let tiny = window(
            id: 1,
            frame: CGRect(x: 80, y: 80, width: size.width, height: size.height),
        )
        let front = window(id: 2)
        let resolution = resolver.resolve(at: point, windows: [tiny, front])
        #expect(resolution == .frontOnly(front))
    }

    @Test
    func `a window of exactly 40 by 40 participates`() {
        let small = window(id: 1, frame: CGRect(x: 80, y: 80, width: 40, height: 40))
        let front = window(id: 2)
        let resolution = resolver.resolve(at: CGPoint(x: 90, y: 90), windows: [small, front])
        #expect(resolution == .peek(PeekTarget(front: small, target: front)))
    }

    // MARK: - Degraded results

    @Test
    func `front with nothing beneath is frontOnly`() {
        let front = window(id: 1)
        #expect(resolver.resolve(at: point, windows: [front]) == .frontOnly(front))
    }

    @Test
    func `no window under the point is nothing`() {
        let elsewhere = window(id: 1, frame: CGRect(x: 900, y: 900, width: 200, height: 200))
        #expect(resolver.resolve(at: point, windows: [elsewhere]) == .nothing)
    }

    @Test
    func `an empty snapshot is nothing`() {
        #expect(resolver.resolve(at: point, windows: []) == .nothing)
    }
}
