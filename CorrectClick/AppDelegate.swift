import Cocoa
import FinderSync

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

    /// Opens System Settings straight to the list of Finder extensions, with
    /// CorrectClick's switch in it. Apple's own API for this, rather than an
    /// `x-apple.systempreferences:` URL: those pane IDs change between macOS
    /// releases (the old `com.apple.preferences.extensions` one silently fell
    /// back to General on macOS 26), and no URL reaches the Finder list
    /// itself — only the Login Items & Extensions pane above it.
    static func openExtensionPreferences() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
