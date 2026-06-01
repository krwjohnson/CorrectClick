import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        checkExtensionStatus()
    }

    private func checkExtensionStatus() {
        // Prompt the user to enable the Finder extension if it isn't already visible.
        // FIFinderSyncController is only available inside the extension process, so we
        // just open the Extensions preference pane on first launch.
        let launchedKey = "hasLaunchedBefore"
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: launchedKey) {
            defaults.set(true, forKey: launchedKey)
            AppDelegate.openExtensionPreferences()
        }
    }

    static func openExtensionPreferences() {
        // macOS 13+ opens the Extensions pane in System Settings.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions") {
            NSWorkspace.shared.open(url)
        }
    }
}
