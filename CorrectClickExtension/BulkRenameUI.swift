import Cocoa
import UserNotifications

/// The interactive side of Bulk Rename (Epic 5): a small input dialog
/// (find/replace or sequential numbering), a preview of the resulting
/// names before anything happens, and a final confirm — the doc's "at
/// minimum, shows a clear confirmation since renames aren't trivially
/// reversible." Kept separate from `FileActions.swift`, which is otherwise
/// plain data-in/data-out actions with no UI of their own.
enum BulkRenameUI {

    static func run(for urls: [URL]) {
        guard !urls.isEmpty else { return }

        // Finder invokes menu actions on a background thread. AppKit throws
        // when an NSAlert is built there, and FIFinderSync catches that
        // exception and drops it — so without this hop the action silently
        // does nothing ("FIFinderSync caught an exception while executing
        // selector" in the log is the only trace).
        guard Thread.isMainThread else {
            DispatchQueue.main.async { run(for: urls) }
            return
        }

        // A Finder Sync extension runs as a background-only process, which
        // can't become the active app — activate() alone is a no-op, and the
        // alert opens behind the front Finder window with no keyboard focus.
        // Becoming an accessory app (still no Dock icon) is what lets it
        // come forward. Afterwards it has to hand focus back explicitly —
        // deactivate() leaves this windowless process as the front app.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        defer {
            NSApp.setActivationPolicy(.prohibited)
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate()
        }

        guard let mode = promptForMode(fileCount: urls.count) else { return } // user cancelled

        let plan = BulkRenamePlan.plan(for: urls, mode: mode)
        let changed = BulkRenamePlan.changedItems(in: plan)
        guard !changed.isEmpty else {
            notify(body: "No filenames would change.")
            return
        }

        let duplicates = BulkRenamePlan.duplicateNewNames(in: changed)
        guard confirmPreview(changed, duplicates: duplicates) else { return }

        apply(changed)
    }

    // MARK: - Step 1: gather find/replace or numbering settings

    private static func promptForMode(fileCount: Int) -> BulkRenameMode? {
        let alert = NSAlert()
        alert.messageText = "Bulk Rename \(fileCount) Item\(fileCount == 1 ? "" : "s")"
        alert.informativeText = "Choose how to rename the selected items."
        alert.addButton(withTitle: "Preview")
        alert.addButton(withTitle: "Cancel")

        let modePicker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        modePicker.addItems(withTitles: ["Find & Replace", "Sequential Numbering"])

        let findField = labeledField(placeholder: "Text to find")
        let replaceField = labeledField(placeholder: "Replace with (blank to remove)")

        let prefixField = labeledField(placeholder: "Prefix (e.g. \"Photo \")")
        let startField = labeledField(placeholder: "Start number", initialValue: "1")
        let paddingField = labeledField(placeholder: "Zero-padding digits (0 for none)", initialValue: "0")

        let findReplaceStack = NSStackView(views: [findField, replaceField])
        findReplaceStack.orientation = .vertical
        findReplaceStack.spacing = 6

        let numberingStack = NSStackView(views: [prefixField, startField, paddingField])
        numberingStack.orientation = .vertical
        numberingStack.spacing = 6
        numberingStack.isHidden = true

        let toggle: (Int) -> Void = { index in
            findReplaceStack.isHidden = index != 0
            numberingStack.isHidden = index != 1
        }
        let handler = PopUpHandler(onChange: toggle)
        modePicker.target = handler
        modePicker.action = #selector(PopUpHandler.selectionChanged(_:))

        let container = NSStackView(views: [modePicker, findReplaceStack, numberingStack])
        container.orientation = .vertical
        container.spacing = 10
        container.alignment = .leading
        container.frame = NSRect(x: 0, y: 0, width: 320, height: 140)

        alert.accessoryView = container
        // Setting initialFirstResponder alone doesn't stick — NSAlert lays
        // itself out lazily and the cursor ends up in no field at all.
        alert.layout()
        alert.window.makeFirstResponder(findField)

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        if modePicker.indexOfSelectedItem == 1 {
            let start = Int(startField.stringValue) ?? 1
            let padding = Int(paddingField.stringValue) ?? 0
            return .sequentialNumbering(prefix: prefixField.stringValue, start: start, padding: max(0, padding))
        } else {
            return .findReplace(find: findField.stringValue, replace: replaceField.stringValue)
        }
    }

    /// Keeps the NSPopUpButton's target alive for the duration of the
    /// alert — NSStackView/NSPopUpButton don't retain their target/action.
    private final class PopUpHandler: NSObject {
        let onChange: (Int) -> Void
        init(onChange: @escaping (Int) -> Void) { self.onChange = onChange }
        @objc func selectionChanged(_ sender: NSPopUpButton) {
            onChange(sender.indexOfSelectedItem)
        }
    }

    private static func labeledField(placeholder: String, initialValue: String = "") -> NSTextField {
        let field = NSTextField(string: initialValue)
        field.placeholderString = placeholder
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 22)
        return field
    }

    // MARK: - Step 2: preview + confirm

    private static func confirmPreview(_ items: [BulkRenameItem], duplicates: Set<String>) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Rename \(items.count) Item\(items.count == 1 ? "" : "s")?"

        let maxLines = 15
        var lines = items.prefix(maxLines).map { "\($0.originalURL.lastPathComponent) → \($0.newName)" }
        if items.count > maxLines {
            lines.append("… and \(items.count - maxLines) more")
        }
        var informative = lines.joined(separator: "\n")
        if !duplicates.isEmpty {
            informative += "\n\n⚠️ Multiple items would be renamed to the same name: \(duplicates.sorted().joined(separator: ", "))"
        }
        alert.informativeText = informative

        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Step 3: apply

    private static func apply(_ items: [BulkRenameItem]) {
        var succeeded = 0
        var failures: [String] = []

        for item in items {
            let destination = item.originalURL.deletingLastPathComponent().appendingPathComponent(item.newName)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                failures.append("\(item.originalURL.lastPathComponent) (a file named \"\(item.newName)\" already exists)")
                continue
            }
            do {
                try FileManager.default.moveItem(at: item.originalURL, to: destination)
                succeeded += 1
            } catch {
                failures.append("\(item.originalURL.lastPathComponent) (\(error.localizedDescription))")
            }
        }

        if failures.isEmpty {
            notify(body: "Renamed \(succeeded) item\(succeeded == 1 ? "" : "s").")
        } else {
            let summary = "Renamed \(succeeded), \(failures.count) failed: \(failures.joined(separator: "; "))"
            notify(body: summary)
        }
    }

    private static func notify(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "CorrectClick"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
