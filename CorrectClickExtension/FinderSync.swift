import Cocoa
import FinderSync
import UserNotifications

class FinderSyncExtension: FIFinderSync {

    override init() {
        super.init()
        // Monitor the entire filesystem so the menu appears in any Finder window.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        requestNotificationPermission()
    }

    // MARK: - Context menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")

        let submenuItem = NSMenuItem(title: "CorrectClick", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "CorrectClick")

        submenu.addItem(withTitle: "New Text File",
                        action: #selector(newTextFile),
                        keyEquivalent: "")
        submenu.addItem(withTitle: "New Text File from Clipboard",
                        action: #selector(newTextFileFromClipboard),
                        keyEquivalent: "")
        submenu.addItem(withTitle: "New PNG from Clipboard",
                        action: #selector(newPNGFromClipboard),
                        keyEquivalent: "")

        submenuItem.submenu = submenu
        menu.addItem(submenuItem)
        return menu
    }

    // MARK: - Actions

    @objc private func newTextFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createTextFile(in: target)
    }

    @objc private func newTextFileFromClipboard() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createTextFileFromClipboard(in: target)
    }

    @objc private func newPNGFromClipboard() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createPNGFromClipboard(in: target)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }
}
