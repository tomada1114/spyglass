import XCTest

/// The template's launch guarantee: the app starts and, with no TCC
/// permissions granted (the deterministic state of a fresh build), shows
/// the onboarding window with its CTA disabled.
///
/// XCTest by necessity — Apple has not ported UI automation to Swift
/// Testing. All other tests use Swift Testing in Packages/SpyglassKit.
final class LaunchTests: XCTestCase {
    private enum Timeout {
        static let windowAppears: TimeInterval = 10
        static let elementAppears: TimeInterval = 5
    }

    @MainActor
    func testAppLaunchesAndShowsOnboarding() {
        // A failed launch assertion should end the test immediately instead of
        // cascading through the remaining waits against a dead app.
        continueAfterFailure = false

        let app = XCUIApplication()
        // XCUITest cannot see windows of an LSUIElement app; this flips the
        // activation policy at launch (a test-visibility shim in the app).
        app.launchEnvironment["XCUI_TEST"] = "1"
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: Timeout.windowAppears))

        let cta = app.buttons["startPeekingButton"]
        XCTAssertTrue(cta.waitForExistence(timeout: Timeout.elementAppears))
        XCTAssertFalse(
            cta.isEnabled,
            "the CTA must stay disabled until both permissions are granted",
        )
    }
}
