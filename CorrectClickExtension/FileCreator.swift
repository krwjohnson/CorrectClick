import Cocoa
import CoreImage
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
        createImageFromClipboard(in: directory, fileType: .png, ext: "png", properties: [:])
    }

    static func createJPGFromClipboard(in directory: URL) {
        createImageFromClipboard(in: directory, fileType: .jpeg, ext: "jpg", properties: [.compressionFactor: 0.9])
    }

    private static func createImageFromClipboard(
        in directory: URL,
        fileType: NSBitmapImageRep.FileType,
        ext: String,
        properties: [NSBitmapImageRep.PropertyKey: Any]
    ) {
        let pasteboard = NSPasteboard.general

        guard let image = NSImage(pasteboard: pasteboard) else {
            notify(body: "Clipboard doesn't contain an image.")
            return
        }

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let encoded = bitmap.representation(using: fileType, properties: properties)
        else {
            notify(body: "Couldn't convert clipboard image to \(ext.uppercased()).")
            return
        }

        let url = uniqueURL(in: directory, stem: "Untitled", ext: ext)
        write(encoded, to: url)
    }

    /// Auto-detects what the clipboard text looks like (Epic 4) and creates
    /// the matching file type: a URL becomes a `.webloc`, JSON-parseable
    /// text becomes a pretty-printed `.json`, everything else becomes
    /// plain `.txt`. WebP isn't offered as an image-from-clipboard format —
    /// AppKit's `NSBitmapImageRep` has no WebP encoder, and adding one would
    /// mean a third-party codec dependency in the sandboxed extension for a
    /// single image format; documented here rather than silently dropped.
    static func createFileFromClipboardAutoDetect(in directory: URL) {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            notify(body: "Clipboard doesn't contain text.")
            return
        }

        switch ClipboardContentDetector.detect(text) {
        case .url(let clipboardURL):
            let url = uniqueURL(in: directory, stem: "Untitled", ext: "webloc")
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>URL</key>
            \t<string>\(clipboardURL.absoluteString)</string>
            </dict>
            </plist>

            """
            write(Data(plist.utf8), to: url)

        case .json:
            let url = uniqueURL(in: directory, stem: "Untitled", ext: "json")
            let formatted: String
            if let parsed = try? OrderedJSONParser.parse(text) {
                formatted = parsed.prettyPrinted() + "\n"
            } else {
                formatted = text // Detector said JSON; re-parsing shouldn't fail, but never lose the content if it somehow does.
            }
            write(Data(formatted.utf8), to: url)

        case .plainText:
            let url = uniqueURL(in: directory, stem: "Untitled", ext: "txt")
            write(Data(text.utf8), to: url)
        }
    }

    /// Encodes the clipboard's text as a QR code PNG (Epic 4), via
    /// CoreImage's built-in `CIQRCodeGenerator` — no third-party dependency
    /// needed. Fails gracefully (a notification, no file) if the clipboard
    /// has no text.
    static func createQRCodeFromClipboard(in directory: URL) {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            notify(body: "Clipboard doesn't contain text to encode.")
            return
        }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            notify(body: "QR code generator isn't available.")
            return
        }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else {
            notify(body: "Couldn't generate a QR code for the clipboard's text.")
            return
        }

        // The raw filter output is tiny (a handful of pixels per module) —
        // scale up so the result is actually usable as an image file.
        let scale: CGFloat = 10
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
            notify(body: "Couldn't render the QR code.")
            return
        }
        guard let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            notify(body: "Couldn't encode the QR code as PNG.")
            return
        }

        let url = uniqueURL(in: directory, stem: "QR Code", ext: "png")
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
    /// For a brand-new blank file the user is about to name; results of an
    /// action on an *existing* file (compress, extract, convert — see
    /// `FileActions.swift`) use `revealAndSelect` instead, without forcing
    /// rename mode.
    private static func triggerRename(for url: URL) {
        revealAndSelect(url)

        // Give Finder time to activate and process the selection before
        // we send the keystroke that triggers inline rename.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            postReturnKey()
        }
    }

    /// Reveals and selects a file in Finder without entering rename mode.
    static func revealAndSelect(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
