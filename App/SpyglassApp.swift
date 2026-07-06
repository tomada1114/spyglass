import AppKit
import SpyglassUI
import SwiftUI

/// Creates the composition root once AppKit is ready; everything else
/// lives in Packages/SpyglassKit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_: Notification) {
        let appController = AppController()
        appController.start()
        controller = appController
    }
}

/// Application entry point — wiring only. The app is LSUIElement: no main
/// window scene, only the menu bar item and the windows AppController owns.
@main
struct SpyglassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
