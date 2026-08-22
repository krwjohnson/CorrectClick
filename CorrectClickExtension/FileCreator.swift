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

    static func createJSONFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "json")
        write(Data("{}\n".utf8), to: url)
    }

    static func createPythonFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "py")
        write(Data("#!/usr/bin/env python3\n".utf8), to: url)
    }

    static func createCSVFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "csv")
        write(Data(), to: url)
    }

    static func createMarkdownFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "md")
        write(Data(), to: url)
    }

    static func createShellScript(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "sh")
        write(Data("#!/bin/zsh\n".utf8), to: url)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    static func createYAMLFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "yaml")
        write(Data(), to: url)
    }

    static func createHTMLFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "html")
        let boilerplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title></title>
        </head>
        <body>

        </body>
        </html>

        """
        write(Data(boilerplate.utf8), to: url)
    }

    static func createTOMLFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "toml")
        write(Data(), to: url)
    }

    static func createXMLFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "xml")
        write(Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".utf8), to: url)
    }

    static func createGitignoreFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: ".gitignore", ext: "")
        write(Data(), to: url)
    }

    static func createLicenseFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "LICENSE", ext: "")
        write(Data(), to: url)
    }

    static func createEnvFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: ".env", ext: "")
        write(Data(), to: url)
    }

    static func createDockerfile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Dockerfile", ext: "")
        write(Data("FROM \n".utf8), to: url)
    }

    static func createSwiftFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "swift")
        write(Data(), to: url)
    }

    static func createSQLFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "sql")
        write(Data(), to: url)
    }

    static func createPlistFile(in directory: URL) {
        let url = uniqueURL(in: directory, stem: "Untitled", ext: "plist")
        let boilerplate = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        </dict>
        </plist>

        """
        write(Data(boilerplate.utf8), to: url)
    }

    static func createFromUserTemplate(_ template: UserTemplate, in directory: URL) {
        let stem = template.fileNameStem
        let url = uniqueURL(in: directory, stem: stem, ext: template.normalizedExtension)

        let context = TemplateContext(
            date: Date(),
            author: AuthorPreferenceStore.load(),
            clipboardText: NSPasteboard.general.string(forType: .string),
            filenameAtCreation: stem
        )
        let content = TemplateVariableSubstitution.resolve(template.starterContent, context: context)
        write(Data(content.utf8), to: url)
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

    /// Returns a URL that doesn't yet exist, incrementing a counter as
    /// needed. Pass an empty `ext` for extensionless/dotfile names (e.g.
    /// `stem: "LICENSE", ext: ""` or `stem: ".gitignore", ext: ""`) — the
    /// counter is still appended before the name would otherwise collide,
    /// matching Finder's own "New Folder" numbering.
    static func uniqueURL(in directory: URL, stem: String, ext: String) -> URL {
        let fm = FileManager.default
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var candidate = directory.appendingPathComponent("\(stem)\(suffix)")
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem) \(counter)\(suffix)")
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
