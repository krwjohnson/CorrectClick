import AppKit
import Sparkle

/// Owns the app's single `SPUStandardUpdaterController` and exposes just
/// what the UI needs — the status bar's "Check for Updates…" item and the
/// Updates preferences tab — so Sparkle imports don't spread everywhere.
final class UpdaterManager {
    static let shared = UpdaterManager()

    let controller: SPUStandardUpdaterController

    private init() {
        // startingUpdater: true — begins scheduling background checks
        // immediately per SUEnableAutomaticChecks / SUScheduledCheckInterval
        // in Info.plist, which the Updates preferences tab can override.
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var updater: SPUUpdater { controller.updater }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
