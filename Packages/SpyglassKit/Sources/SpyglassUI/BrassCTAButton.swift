import SwiftUI

/// Fixed numbers for the primary CTA (`docs/design.md` §7).
private enum Metrics {
    static let width: CGFloat = 376
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 10
    static let fontSize: CGFloat = 15
    static let disabledOpacity = 0.35
    static let hoverBrightness = 0.06
    static let pressedScale: CGFloat = 0.98
    static let enableFadeSeconds = 0.2
}

/// Press feedback + gradient fill, split from the view because
/// `configuration.isPressed` only exists inside a `ButtonStyle`.
private struct BrassButtonStyle: ButtonStyle {
    let hovering: Bool

    @Environment(\.colorScheme)
    private var colorScheme
    @Environment(\.isEnabled)
    private var isEnabled

    /// 180° gradient — brand stops swap between appearances (design §7).
    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [.brassBright, .brassMid]
            : [.brassMid, .brassDeep]
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Metrics.fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Metrics.width, height: Metrics.height)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom,
                ),
                in: RoundedRectangle(cornerRadius: Metrics.cornerRadius),
            )
            .brightness(hovering && isEnabled ? Metrics.hoverBrightness : 0)
            .scaleEffect(configuration.isPressed ? Metrics.pressedScale : 1)
            .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
            .animation(.easeInOut(duration: Metrics.enableFadeSeconds), value: isEnabled)
    }
}

/// The single primary button of the onboarding window (also used for the
/// Relaunch variant — same size and style, different label and action).
struct BrassCTAButton: View {
    let title: String
    /// Applied to the `Button` element itself so XCUITest's `app.buttons`
    /// query finds it (an identifier on a wrapper view does not surface).
    let identifier: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(title, action: action)
            .buttonStyle(BrassButtonStyle(hovering: hovering))
            .onHover { hovering = $0 }
            .accessibilityIdentifier(identifier)
    }
}
