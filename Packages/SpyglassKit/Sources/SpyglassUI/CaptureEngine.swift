import AppKit
import os
import ScreenCaptureKit
import SpyglassCore

/// CIContext is documented thread-safe and this box exposes it immutably —
/// the invariant `@unchecked Sendable` papers over.
private final class FrameConverter: @unchecked Sendable {
    private let context = CIContext()

    func cgImage(from buffer: CVPixelBuffer) -> CGImage? {
        let image = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(image, from: image.extent)
    }
}

/// One SCStream at a time, for the current target window only.
///
/// `SCContentFilter(desktopIndependentWindow:)` keeps streaming full window
/// content even while the window is occluded — the sanctioned mechanism the
/// whole product rests on. Screenshot polling is a rejected design.
@MainActor
final class CaptureEngine: NSObject, SCStreamDelegate, SCStreamOutput {
    private enum Config {
        static let framesPerSecond: CMTimeScale = 30
        static let fallbackScale: CGFloat = 2
    }

    private static let logger = Logger(
        subsystem: "io.github.tomada1114.Spyglass",
        category: "capture",
    )

    /// Delivered on the main actor for every decoded frame.
    var onFrame: ((CGImage) -> Void)?
    /// Fired when the stream dies unexpectedly (the lens shows empty state).
    var onStopped: (() -> Void)?

    private let converter = FrameConverter()
    private let sampleQueue = DispatchQueue(label: "io.github.tomada1114.Spyglass.capture")
    private var stream: SCStream?
    /// Invalidates in-flight `start` calls when the target changes mid-await.
    private var generation = 0

    /// Starts streaming `windowID`, tearing down any previous stream.
    func start(windowID: WindowID) async {
        generation += 1
        let requestGeneration = generation
        await teardown()
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true,
            )
            guard generation == requestGeneration else {
                return
            }
            guard let target = content.windows.first(where: { $0.windowID == windowID }) else {
                onStopped?()
                return
            }
            let newStream = SCStream(
                filter: SCContentFilter(desktopIndependentWindow: target),
                configuration: configuration(for: target),
                delegate: self,
            )
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try await newStream.startCapture()
            guard generation == requestGeneration else {
                try? await newStream.stopCapture()
                return
            }
            stream = newStream
        } catch {
            Self.logger.error("stream start failed: \(error.localizedDescription)")
            onStopped?()
        }
    }

    /// Stops the current stream, if any.
    func stop() {
        generation += 1
        let dying = stream
        stream = nil
        Task {
            try? await dying?.stopCapture()
        }
    }

    nonisolated func stream(
        _ sourceStream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType,
    ) {
        guard
            type == .screen,
            sampleBuffer.isValid,
            let buffer = sampleBuffer.imageBuffer,
            let image = converter.cgImage(from: buffer)
        else {
            return
        }
        let source = ObjectIdentifier(sourceStream)
        Task { @MainActor in
            // Drop late frames from an outgoing stream so a swap never renders
            // window A's pixels cropped as window B.
            guard self.stream.map(ObjectIdentifier.init) == source else {
                return
            }
            self.onFrame?(image)
        }
    }

    nonisolated func stream(_: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            Self.logger.error("stream stopped: \(error.localizedDescription)")
            self.stream = nil
            self.onStopped?()
        }
    }

    private func teardown() async {
        guard let stream else {
            return
        }
        self.stream = nil
        try? await stream.stopCapture()
    }

    /// 30 fps, no cursor, pixel size = window points × display scale
    /// (`docs/requirements.md` §2.1).
    private func configuration(for window: SCWindow) -> SCStreamConfiguration {
        let scale = displayScale(for: window)
        let config = SCStreamConfiguration()
        config.minimumFrameInterval = CMTime(value: 1, timescale: Config.framesPerSecond)
        config.showsCursor = false
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        return config
    }

    /// Backing scale of the display the target window mostly sits on
    /// (requirements §2.1: the scale is the *target's* display, not the main
    /// one). `window.frame` is CG top-left space, so flip it to AppKit before
    /// intersecting the NSScreen frames.
    private func displayScale(for window: SCWindow) -> CGFloat {
        let frameAppKit = LensGeometry.cgToAppKit(
            rect: window.frame,
            mainDisplayHeight: NSScreen.screens.first?.frame.height ?? 0,
        )
        let best = NSScreen.screens.max { lhs, rhs in
            let lhsArea = lhs.frame.intersection(frameAppKit)
            let rhsArea = rhs.frame.intersection(frameAppKit)
            return lhsArea.width * lhsArea.height < rhsArea.width * rhsArea.height
        }
        return best?.backingScaleFactor ?? Config.fallbackScale
    }
}
