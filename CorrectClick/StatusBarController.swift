import Cocoa

final class StatusBarController {

    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "CorrectClick")
            button.toolTip = "CorrectClick"
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let enableItem = NSMenuItem(
            title: "Enable Finder Extension…",
            action: #selector(openExtensionPreferences),
            keyEquivalent: ""
        )
        enableItem.target = self
        menu.addItem(enableItem)

        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        let uninstallItem = NSMenuItem(
            title: "Uninstall CorrectClick…",
            action: #selector(uninstall),
            keyEquivalent: ""
        )
        uninstallItem.target = self
        menu.addItem(uninstallItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit CorrectClick",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openExtensionPreferences() {
        OnboardingWindowController.shared.show()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func checkForUpdates() {
        UpdaterManager.shared.checkForUpdates()
    }

    @objc private func uninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall CorrectClick?"
        alert.informativeText = "This opens Terminal to remove CorrectClick, its Finder extension, and its saved settings. You'll get a chance to confirm again there."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let scriptURL = Bundle.main.url(forResource: "Uninstall CorrectClick", withExtension: "command") else {
            return
        }

        // NSWorkspace.open(_:) can't hand a document to another app under App
        // Sandbox ("not allowed to open documents in Terminal"), so script
        // Terminal directly via Apple Events instead. The path is quoted for
        // the shell (it contains spaces), then that whole quoted command is
        // escaped again for the AppleScript string literal.
        let shellCommand = "\"\(scriptURL.path)\""
        let escapedForAppleScript = shellCommand.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "\(escapedForAppleScript)"
        end tell
        """
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                NSLog("Failed to launch uninstaller in Terminal: \(error)")
            }
        }
    }
}
