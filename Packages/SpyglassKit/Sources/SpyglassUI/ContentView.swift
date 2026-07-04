import SpyglassCore
import SwiftUI

/// Layout metrics for ``ContentView``.
private enum Layout {
    static let stackSpacing: CGFloat = 16
    static let valueFontSize: CGFloat = 48
    static let windowPadding: CGFloat = 32
    static let minWindowWidth: CGFloat = 320
    static let minWindowHeight: CGFloat = 240
}

/// The app's single screen: a bounded counter with increment/decrement/reset.
///
/// Deliberately thin — every behavior it renders is owned and unit-tested by
/// `CounterViewModel` in SpyglassCore.
public struct ContentView: View {
    @State private var model: CounterViewModel

    public var body: some View {
        VStack(spacing: Layout.stackSpacing) {
            Text("\(model.value)")
                .font(.system(size: Layout.valueFontSize, weight: .bold, design: .rounded))
                .accessibilityIdentifier("counterValue")
            HStack {
                Button("−") { model.decrement() }
                    .disabled(!model.canDecrement)
                    .accessibilityIdentifier("decrementButton")
                Button("Reset") { model.reset() }
                    .accessibilityIdentifier("resetButton")
                Button("+") { model.increment() }
                    .disabled(!model.canIncrement)
                    .accessibilityIdentifier("incrementButton")
            }
        }
        .padding(Layout.windowPadding)
        .frame(minWidth: Layout.minWindowWidth, minHeight: Layout.minWindowHeight)
    }

    /// Creates the view over `model` — previews and tests inject alternate
    /// states; the app shell uses the default.
    public init(model: CounterViewModel = CounterViewModel()) {
        _model = State(initialValue: model)
    }
}

#Preview("Default") {
    ContentView()
}

#Preview("At the upper bound") {
    if let counter = try? Counter(value: 100) {
        ContentView(model: CounterViewModel(counter: counter))
    }
}
