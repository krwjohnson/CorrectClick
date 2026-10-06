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

    // MARK: - Toolbar button

    // Finder doesn't show any Finder Sync extension's right-click menu inside
    // File Provider locations (iCloud Drive, OneDrive, Dropbox, and anything
    // else under ~/Library/CloudStorage) — Apple has confirmed this is by
    // design. Toolbar buttons are still shown there, so this button (added
    // via Finder's View → Customize Toolbar…) is how the same menu reaches
    // those folders. Finder asks for its menu via
    // `menu(for: .toolbarItemMenu)`, below.

    override var toolbarItemName: String {
        "CorrectClick"
    }

    override var toolbarItemToolTip: String {
        "CorrectClick: create files and run file actions in this folder"
    }

    override var toolbarItemImage: NSImage {
        let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "CorrectClick")
            ?? NSImage(named: NSImage.actionTemplateName)!
        image.isTemplate = true
        return image
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let items = NSMenu(title: "CorrectClick")
        populate(items)

        // The toolbar button already *is* CorrectClick, so its menu lists
        // the actions directly. Right-click menus are shared with Finder and
        // every other extension, so there they go in a "CorrectClick" submenu.
        if menuKind == .toolbarItemMenu {
            return items
        }

        let menu = NSMenu(title: "")
        let submenuItem = NSMenuItem(title: "CorrectClick", action: nil, keyEquivalent: "")
        submenuItem.submenu = items
        menu.addItem(submenuItem)
        return menu
    }

    private func populate(_ submenu: NSMenu) {
        // Read preferences and templates fresh on every invocation — Finder
        // calls this on each right-click and toolbar-button click, so this
        // is the natural place to pick up changes made in the app's
        // Preferences window without any extra IPC or an explicit
        // FIFinderSyncController invalidate call.
        let store = MenuPreferencesStore.shared
        let states = store.load()
        let createItems = store.enabledOrderedItems(in: .create, from: states)
        let clipboardItems = store.enabledOrderedItems(in: .clipboard, from: states)
        let userTemplates = UserTemplateStore.shared.enabledOrdered(from: UserTemplateStore.shared.load())

        // fileUtility items (Epics 4/5/6) additionally need to make sense
        // for the current selection — e.g. "Extract ZIP" only for a single
        // selected .zip — on top of just being enabled in preferences.
        let selection = FIFinderSyncController.default().selectedItemURLs() ?? []
        let fileUtilityItems = store.enabledOrderedItems(in: .fileUtility, from: states)
            .filter { isApplicable($0, selection: selection) }

        // Built as separate sections with a divider between any two
        // non-empty ones — whichever items/templates are enabled or
        // applicable, this never produces a doubled-up or leading/trailing
        // separator.
        appendSection(createItems.map(builtInMenuItem), to: submenu)
        appendSection(clipboardItems.map(builtInMenuItem), to: submenu)
        appendSection(userTemplates.map(userTemplateMenuItem), to: submenu)
        appendSection(fileUtilityItems.map(builtInMenuItem), to: submenu)
    }

    /// Preferences only govern enabled/order — this is the additional,
    /// per-invocation check for whether an item makes sense given what's
    /// actually selected right now. See `Shared/FileUtilityApplicability.swift`
    /// for the (unit-tested) logic itself.
    private func isApplicable(_ item: MenuItemDefinition, selection: [URL]) -> Bool {
        FileUtilityApplicability.isApplicable(id: item.id, selection: selection)
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
        "jpgFromClipboard": #selector(newJPGFromClipboard),
        "clipboardAutoDetect": #selector(newFileFromClipboardAutoDetect),
        "qrCodeFromClipboard": #selector(newQRCodeFromClipboard),
        "copyPOSIXPath": #selector(copyPOSIXPathAction),
        "copyShellEscapedPath": #selector(copyShellEscapedPathAction),
        "copyFileURL": #selector(copyFileURLAction),
        "copyMarkdownLink": #selector(copyMarkdownLinkAction),
        "newTerminalHere": #selector(newTerminalHereAction),
        "copyBase64": #selector(copyBase64Action),
        "generateHash": #selector(generateHashAction),
        "compressToZip": #selector(compressToZipAction),
        "extractZip": #selector(extractZipAction),
        "bulkRename": #selector(bulkRenameAction),
        "csvToJSON": #selector(csvToJSONAction),
        "jsonToCSV": #selector(jsonToCSVAction),
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

    @objc private func newJPGFromClipboard() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createJPGFromClipboard(in: target)
    }

    @objc private func newFileFromClipboardAutoDetect() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createFileFromClipboardAutoDetect(in: target)
    }

    @objc private func newQRCodeFromClipboard() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileCreator.createQRCodeFromClipboard(in: target)
    }

    // MARK: - File utility actions (Epics 4/5/6)

    private var selectedItems: [URL] {
        FIFinderSyncController.default().selectedItemURLs() ?? []
    }

    @objc private func copyPOSIXPathAction() {
        FileActions.copyPOSIXPath(for: selectedItems)
    }

    @objc private func copyShellEscapedPathAction() {
        FileActions.copyShellEscapedPath(for: selectedItems)
    }

    @objc private func copyFileURLAction() {
        FileActions.copyFileURL(for: selectedItems)
    }

    @objc private func copyMarkdownLinkAction() {
        FileActions.copyMarkdownLink(for: selectedItems)
    }

    @objc private func newTerminalHereAction() {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        FileActions.openTerminal(in: target)
    }

    @objc private func copyBase64Action() {
        guard let url = selectedItems.first else { return }
        FileActions.copyBase64(for: url)
    }

    @objc private func generateHashAction() {
        guard let url = selectedItems.first else { return }
        FileActions.generateHash(for: url)
    }

    @objc private func compressToZipAction() {
        FileActions.compressToZip(selectedItems)
    }

    @objc private func extractZipAction() {
        guard let url = selectedItems.first else { return }
        FileActions.extractZip(url)
    }

    @objc private func bulkRenameAction() {
        FileActions.bulkRename(selectedItems)
    }

    @objc private func csvToJSONAction() {
        guard let url = selectedItems.first else { return }
        FileActions.convertCSVToJSON(url)
    }

    @objc private func jsonToCSVAction() {
        guard let url = selectedItems.first else { return }
        FileActions.convertJSONToCSV(url)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }
}
