import CoreGraphics

/// A CoreGraphics window number (`kCGWindowNumber`).
public typealias WindowID = UInt32

/// One on-screen window as reported by `CGWindowListCopyWindowInfo`.
///
/// `frame` is in CG global coordinates — origin at the top-left of the main
/// display, y growing downward. Conversion to AppKit space happens only in
/// ``LensGeometry``.
public struct WindowInfo: Equatable, Sendable {
    /// The CG window number, also the key for ScreenCaptureKit lookup.
    public let id: WindowID
    /// Window bounds in CG global (top-left origin) coordinates.
    public let frame: CGRect
    /// `kCGWindowLayer` — 0 for normal document windows.
    public let layer: Int
    /// `kCGWindowAlpha` — 0 means fully transparent.
    public let alpha: Double
    /// Owning process, used for raise-and-activate.
    public let ownerPID: Int32
    /// `kCGWindowName`, when the caller may read it.
    public let title: String?
    /// `kCGWindowOwnerName`, for the caption pill.
    public let appName: String?
    /// True for Spyglass's own windows (lens overlay, settings…), which must
    /// never be peeked at or through.
    public let isOwnWindow: Bool

    /// Creates a snapshot entry; the UI layer's enumerator is the only
    /// production caller.
    public init(
        id: WindowID,
        frame: CGRect,
        layer: Int,
        alpha: Double,
        ownerPID: Int32,
        title: String?,
        appName: String?,
        isOwnWindow: Bool,
    ) {
        self.id = id
        self.frame = frame
        self.layer = layer
        self.alpha = alpha
        self.ownerPID = ownerPID
        self.title = title
        self.appName = appName
        self.isOwnWindow = isOwnWindow
    }
}
