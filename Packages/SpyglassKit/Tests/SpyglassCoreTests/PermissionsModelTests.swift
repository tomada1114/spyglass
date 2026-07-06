import SpyglassCore
import Testing

@Suite("PermissionsModel")
struct PermissionsModelTests {
    private func model(
        screenRecording: Bool,
        accessibility: Bool,
        grantedThisSession: Bool = false,
    ) -> PermissionsModel {
        PermissionsModel(
            screenRecording: screenRecording,
            accessibility: accessibility,
            grantedThisSession: grantedThisSession,
        )
    }

    // MARK: - Onboarding CTA

    @Test(arguments: [
        (false, false),
        (false, true),
        (true, false),
    ])
    func `any missing permission disables the CTA`(screenRecording: Bool, accessibility: Bool) {
        let model = model(screenRecording: screenRecording, accessibility: accessibility)
        #expect(model.onboardingCTA == .disabled)
    }

    @Test
    func `both permissions granted before launch enable start peeking`() {
        let model = model(screenRecording: true, accessibility: true)
        #expect(model.onboardingCTA == .startPeeking)
    }

    @Test(arguments: [true, false])
    func `screen recording granted in-session always demands a relaunch`(accessibility: Bool) {
        let model = model(
            screenRecording: true,
            accessibility: accessibility,
            grantedThisSession: true,
        )
        #expect(model.onboardingCTA == .relaunch)
    }

    // MARK: - Menu bar state

    @Test
    func `menu bar warns while any permission is missing`() {
        #expect(model(screenRecording: false, accessibility: true).menuBarState == .warning)
        #expect(model(screenRecording: true, accessibility: false).menuBarState == .warning)
        #expect(model(screenRecording: true, accessibility: true).menuBarState == .normal)
    }
}
