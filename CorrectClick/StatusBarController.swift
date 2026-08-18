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
}
