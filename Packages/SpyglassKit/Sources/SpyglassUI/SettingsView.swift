import SpyglassCore
import SwiftUI

/// Fixed numbers for the settings window (`docs/design.md` §6).
private enum Metrics {
    static let width: CGFloat = 400
    static let height: CGFloat = 360
    static let sectionSpacing: CGFloat = 16
    static let captionSize: CGFloat = 13
    static let captionSpacing: CGFloat = 4
    static let boxCornerRadius: CGFloat = 10
    static let boxPadding: CGFloat = 12
    static let windowPadding: CGFloat = 16
    static let readoutSize: CGFloat = 12
    static let errorSize: CGFloat = 12
    static let previewScale: CGFloat = 4
    static let innerSpacing: CGFloat = 8
}

/// One purpose-built group box — the stock grouped `Form` reads as
/// templated (design §6), so sections are composed by hand.
private struct SettingsSection<Content: View>: View {
    let caption: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.captionSpacing) {
            Text(caption)
                .font(.system(size: Metrics.captionSize, weight: .semibold))
            VStack(spacing: Metrics.innerSpacing) {
                content
            }
            .padding(Metrics.boxPadding)
            .frame(maxWidth: .infinity)
            .background(
                .quinary,
                in: RoundedRectangle(cornerRadius: Metrics.boxCornerRadius),
            )
        }
    }
}

/// The three-control settings surface (wireframes §2). Every change applies
/// immediately: values persist through `SettingsStore` and the login item
/// registers on toggle, with the inline recovery text on failure.
public struct SettingsView: View {
    private let settings: SettingsStore
    private let loginItems: LoginItemService

    @State private var triggerKey: TriggerKey
    @State private var diameter: Double
    @State private var launchAtLogin: Bool
    @State private var loginItemErrorVisible = false

    public var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            triggerSection
            lensSection
            generalSection
        }
        .padding(Metrics.windowPadding)
        .frame(width: Metrics.width, height: Metrics.height, alignment: .top)
    }

    private var triggerSection: some View {
        SettingsSection(caption: "Trigger") {
            HStack {
                Text("Hold to peek")
                Spacer()
                Picker("Hold to peek", selection: $triggerKey) {
                    Text("Right ⌘").tag(TriggerKey.rightCommand)
                    Text("⌃⌥").tag(TriggerKey.controlOption)
                    Text("fn").tag(TriggerKey.fnKey)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .onChange(of: triggerKey) { _, newValue in
                    settings.triggerKey = newValue
                }
            }
        }
    }

    private var lensSection: some View {
        SettingsSection(caption: "Lens") {
            HStack {
                Text("Size")
                Slider(
                    value: $diameter,
                    in: SettingsStore.diameterRange,
                    step: SettingsStore.diameterStep,
                )
                .tint(.brassPrimary)
                .onChange(of: diameter) { _, newValue in
                    settings.lensDiameter = newValue
                }
            }
            preview
            Text("\(Int(diameter)) pt")
                .font(.system(size: Metrics.readoutSize))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    /// The real `LensView` at ¼ scale — the settings window doubles as a
    /// living spec of the hero visual.
    private var preview: some View {
        LensView(diameter: diameter, content: .settingsPlaceholder)
            .scaleEffect(1 / Metrics.previewScale)
            .frame(
                width: diameter / Metrics.previewScale,
                height: diameter / Metrics.previewScale,
            )
    }

    private var generalSection: some View {
        SettingsSection(caption: "General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    applyLoginItem(newValue)
                }
            if loginItemErrorVisible {
                Text("Couldn't register — check System Settings › Login Items")
                    .font(.system(size: Metrics.errorSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Binds the view to persistence; state seeds from the stored values.
    public init(settings: SettingsStore, loginItems: LoginItemService) {
        self.settings = settings
        self.loginItems = loginItems
        _triggerKey = State(initialValue: settings.triggerKey)
        _diameter = State(initialValue: settings.lensDiameter)
        _launchAtLogin = State(initialValue: settings.launchAtLogin)
    }

    private func applyLoginItem(_ enabled: Bool) {
        do {
            try loginItems.setEnabled(enabled)
            settings.launchAtLogin = enabled
            loginItemErrorVisible = false
        } catch {
            launchAtLogin = loginItems.isEnabled
            loginItemErrorVisible = true
        }
    }
}

#Preview("Settings") {
    SettingsView(
        settings: SettingsStore(persistence: UserDefaultsPersistence()),
        loginItems: LoginItemService(),
    )
}
