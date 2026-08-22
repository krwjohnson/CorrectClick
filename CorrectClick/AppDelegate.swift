import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        // Starts Sparkle's scheduled update checks (Epic 3). Touching
        // `.shared` here is what creates the SPUStandardUpdaterController —
        // do this before anything else might reference it.
        _ = UpdaterManager.shared
        // Defer until the run loop is running so the window can come to front
        // correctly from an LSUIElement (no-Dock-icon) app.
        DispatchQueue.main.async {
            OnboardingWindowController.shared.showIfNeeded()
        }
    }

    static func openExtensionPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions") {
            NSWorkspace.shared.open(url)
        }
    }
}
