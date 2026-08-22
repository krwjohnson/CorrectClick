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

        // Read preferences and templates fresh on every invocation — Finder
        // calls this on each right-click, so this is the natural place to
        // pick up changes made in the app's Preferences window without any
        // extra IPC or an explicit FIFinderSyncController invalidate call.
        let store = MenuPreferencesStore.shared
        let states = store.load()
        let createItems = store.enabledOrderedItems(in: .create, from: states)
        let clipboardItems = store.enabledOrderedItems(in: .clipboard, from: states)
        let userTemplates = UserTemplateStore.shared.enabledOrdered(from: UserTemplateStore.shared.load())

        // Built as separate sections (New File, From Clipboard, user
        // templates) with a divider between any two non-empty ones —
        // whichever built-in items or templates are enabled, this never
        // produces a doubled-up or leading/trailing separator.
        appendSection(createItems.map(builtInMenuItem), to: submenu)
        appendSection(clipboardItems.map(builtInMenuItem), to: submenu)
        appendSection(userTemplates.map(userTemplateMenuItem), to: submenu)

        submenuItem.submenu = submenu
        menu.addItem(submenuItem)
        return menu
    }

    private func appendSection(_ items: [NSMenuItem], to menu: NSMenu) {
        guard !items.isEmpty else { return }
        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        items.forEach(menu.addItem)
    }

    private func builtInMenuItem(for item: MenuItemDefinition) -> NSMenuItem {
        let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
        if let selector = Self.actionSelectors[item.id] {
            menuItem.action = selector
        }
        return menuItem
    }

    /// User templates share one generic handler (`newFromUserTemplate`,
    /// below) rather than a per-id selector, since they're defined at
    /// runtime — the template's id travels via `representedObject`.
    private func userTemplateMenuItem(for template: UserTemplate) -> NSMenuItem {
        let menuItem = NSMenuItem(title: template.displayName, action: #selector(newFromUserTemplate(_:)), keyEquivalent: "")
        menuItem.representedObject = template.id
        return menuItem
    }

    /// Maps each `MenuItemDefinition.id` (see Shared/MenuItemPreferences.swift)
    /// to the @objc handler that creates that file type.
    private static let actionSelectors: [String: Selector] = [
        "text": #selector(newTextFile),
        "json": #selector(newJSONFile),
        "python": #selector(newPythonFile),
        "csv": #selector(newCSVFile),
        "markdown": #selector(newMarkdownFile),
        "shell": #selector(newShellScript),
        "yaml": #selector(newYAMLFile),
        "html": #selector(newHTMLFile),
        "toml": #selector(newTOMLFile),
        "xml": #selector(newXMLFile),
        "gitignore": #selector(newGitignoreFile),
        "license": #selector(newLicenseFile),
        "env": #selector(newEnvFile),
        "dockerfile": #selector(newDockerfile),
        "swift": #selector(newSwiftFile),
        "sql": #selector(newSQLFile),
        "plist": #selector(newPlistFile),
        "textFromClipboard": #selector(newTextFileFromClipboard),
        "pngFromClipboard": #selector(newPNGFromClipboard),
    ]

    // MARK: - Actions

    @objc private func newTextFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createTextFile(in: target)
    }

    @objc private func newJSONFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createJSONFile(in: target)
    }

    @objc private func newPythonFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createPythonFile(in: target)
    }

    @objc private func newCSVFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createCSVFile(in: target)
    }

    @objc private func newMarkdownFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createMarkdownFile(in: target)
    }

    @objc private func newShellScript() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createShellScript(in: target)
    }

    @objc private func newYAMLFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createYAMLFile(in: target)
    }

    @objc private func newHTMLFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createHTMLFile(in: target)
    }

    @objc private func newTOMLFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createTOMLFile(in: target)
    }

    @objc private func newXMLFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createXMLFile(in: target)
    }

    @objc private func newGitignoreFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createGitignoreFile(in: target)
    }

    @objc private func newLicenseFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createLicenseFile(in: target)
    }

    @objc private func newEnvFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createEnvFile(in: target)
    }

    @objc private func newDockerfile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createDockerfile(in: target)
    }

    @objc private func newSwiftFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createSwiftFile(in: target)
    }

    @objc private func newSQLFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createSQLFile(in: target)
    }

    @objc private func newPlistFile() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createPlistFile(in: target)
    }

    @objc private func newFromUserTemplate(_ sender: NSMenuItem) {
        guard
            let target = FIFinderSyncController.default().targetedURL(),
            let id = sender.representedObject as? UUID
        else { return }

        guard let template = UserTemplateStore.shared.load().first(where: { $0.id == id }) else {
            // The template was deleted between the menu being built and the
            // click landing — rare, but shouldn't crash the extension.
            return
        }
        FileCreator.createFromUserTemplate(template, in: target)
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
