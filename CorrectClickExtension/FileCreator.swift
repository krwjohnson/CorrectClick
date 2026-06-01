import Cocoa
import UserNotifications

enum FileCreator {

    // MARK: - Public entry points

    static func createTextFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "txt")
        write(Data(), to: url)
    }

    static func createTextFileFromClipboard(in directory: URL) {
        let pasteboard = NSPasteboard.general

        // Prefer plain text; fall back to stripping RTF.
        if let plain = pasteboard.string(forType: .string) {
            let url = uniqueURL(in: directory, stem: "Untitled", ext: "txt")
            write(Data(plain.utf8), to: url)
            return
        }

        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            let url = uniqueURL(in: directory, stem: "Untitled", ext: "txt")
            write(Data(attributed.string.utf8), to: url)
            return
        }

        notify(body: "Clipboard doesn't contain usable text.")
    }

    static func createPNGFromClipboard(in directory: URL) {
        let pasteboard = NSPasteboard.general

        guard let image = NSImage(pasteboard: pasteboard) else {
            notify(body: "Clipboard doesn't contain an image.")
            return
        }

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            notify(body: "Couldn't convert clipboard image to PNG.")
            return
        }

        let url = uniqueURL(in: directory, stem: "Untitled", ext: "png")
        write(png, to: url)
    }

    // MARK: - Helpers

    private static func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
            triggerRename(for: url)
        } catch {
            notify(body: "Couldn't create file: \(error.localizedDescription)")
        }
    }

    /// Returns a URL that doesn't yet exist, incrementing a counter as needed.
    static func uniqueURL(in directory: URL, stem: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent("\(stem).\(ext)")
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    /// Reveals and selects the file in Finder, then posts a Return key event to
    /// enter rename mode — matching Finder's own "New Folder" behaviour.
    private static func triggerRename(for url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])

        // Give Finder time to activate and process the selection before
        // we send the keystroke that triggers inline rename.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            postReturnKey()
        }
    }

    /// Synthesises a Return key press directed at the frontmost app (Finder).
    private static func postReturnKey() {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyCode: CGKeyCode = 0x24 // Return
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)?.post(tap: .cgSessionEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)?.post(tap: .cgSessionEventTap)
    }

    private static func notify(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "CorrectClick"
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
