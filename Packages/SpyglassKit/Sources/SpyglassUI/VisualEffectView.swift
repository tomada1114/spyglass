import AppKit
import SwiftUI

/// SwiftUI wrapper for `NSVisualEffectView` — the real-vibrancy frosted fill
/// the lens empty state requires (`docs/design.md` §4 State B). SwiftUI's
/// `Material` is not used because the spec pins the AppKit `.hudWindow`
/// material with `.behindWindow` blending.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        view.material = material
    }
}
