import Cocoa
import UserNotifications
import ZIPFoundation

/// Actions that operate on an already-selected file (or the current
/// folder, for "New Terminal Here") rather than creating a templated new
/// file — Epics 4/5/6. Kept separate from `FileCreator.swift`, which is
/// entirely "create something new in this directory."
enum FileActions {

    // MARK: - Copy path variants (Epic 5)

    static func copyPOSIXPath(for urls: [URL]) {
        copyToPasteboard(PathFormatting.joined(urls, format: PathFormatting.posixPath))
    }

    static func copyShellEscapedPath(for urls: [URL]) {
        copyToPasteboard(PathFormatting.joined(urls, format: PathFormatting.shellEscapedPath))
    }

    static func copyFileURL(for urls: [URL]) {
        copyToPasteboard(PathFormatting.joined(urls, format: PathFormatting.fileURLString))
    }

    static func copyMarkdownLink(for urls: [URL]) {
        copyToPasteboard(PathFormatting.joined(urls, format: PathFormatting.markdownLink))
    }

    // MARK: - Base64 (Epic 4)

    /// Reads and encodes off the main thread — required per the
    /// requirements doc for any action on a potentially-large file, so a
    /// multi-hundred-MB selection doesn't block Finder's UI.
    static func copyBase64(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url) else {
                notify(body: "Couldn't read \"\(url.lastPathComponent)\".")
                return
            }
            let base64 = data.base64EncodedString()
            DispatchQueue.main.async {
                copyToPasteboard(base64)
                notify(body: "Copied Base64 for \"\(url.lastPathComponent)\" to the clipboard.")
            }
        }
    }

    // MARK: - File hash (Epic 5)

    static func generateHash(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url) else {
                notify(body: "Couldn't read \"\(url.lastPathComponent)\".")
                return
            }
            let digests = FileHashing.digests(for: data)
            let text = "MD5: \(digests.md5)\nSHA-256: \(digests.sha256)"
            DispatchQueue.main.async {
                copyToPasteboard(text)
                notify(body: "Copied MD5 & SHA-256 for \"\(url.lastPathComponent)\" to the clipboard.")
            }
        }
    }

    // MARK: - Compress / extract (Epic 5, via ZIPFoundation)

    /// Zips the given items together into one archive alongside them —
    /// runs off the main thread since archiving can be slow for a large
    /// selection.
    static func compressToZip(_ urls: [URL]) {
        guard let first = urls.first else { return }
        let directory = first.deletingLastPathComponent()
        let stem = urls.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
        let destination = FileCreator.uniqueURL(in: directory, stem: stem, ext: "zip")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let archive = try Archive(url: destination, accessMode: .create)
                for url in urls {
                    // addEntry(relativeTo:) recurses directories on its own.
                    try archive.addEntry(
                        with: url.lastPathComponent,
                        relativeTo: url.deletingLastPathComponent(),
                        compressionMethod: .deflate
                    )
                }
                DispatchQueue.main.async {
                    FileCreator.revealAndSelect(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    notify(body: "Couldn't create the ZIP archive: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Extracts a single selected `.zip` alongside itself, into a
    /// same-named folder. `.tar.gz` isn't supported — that needs a tar
    /// container reader on top of gzip decompression, out of scope for the
    /// one archive dependency (ZIPFoundation, zip-only) approved for this
    /// phase; documented here rather than silently unsupported.
    static func extractZip(_ url: URL) {
        let directory = url.deletingLastPathComponent()
        let destination = FileCreator.uniqueURL(in: directory, stem: url.deletingPathExtension().lastPathComponent, ext: "")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: url, to: destination)
                DispatchQueue.main.async {
                    FileCreator.revealAndSelect(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    notify(body: "Couldn't extract the archive: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - CSV <-> JSON conversion (Epic 6)

    static func convertCSVToJSON(_ url: URL) {
        convert(url, newExtension: "json") { try CSVJSONConversion.csvToJSON($0) }
    }

    static func convertJSONToCSV(_ url: URL) {
        convert(url, newExtension: "csv") { try CSVJSONConversion.jsonToCSV($0) }
    }

    /// Shared by both conversion directions: reads off the main thread
    /// (handles a large CSV/JSON file without freezing Finder), never
    /// touches the source file, and reports a parse failure as a
    /// notification rather than writing a corrupted/partial output file.
    private static func convert(_ url: URL, newExtension: String, transform: @escaping (String) throws -> String) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                DispatchQueue.main.async {
                    notify(body: "Couldn't read \"\(url.lastPathComponent)\" as text.")
                }
                return
            }

            do {
                let converted = try transform(text)
                let destination = FileCreator.uniqueURL(
                    in: url.deletingLastPathComponent(),
                    stem: url.deletingPathExtension().lastPathComponent,
                    ext: newExtension
                )
                try converted.write(to: destination, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    FileCreator.revealAndSelect(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    notify(body: "Couldn't convert \"\(url.lastPathComponent)\": \(message)")
                }
            }
        }
    }

    // MARK: - Bulk rename (Epic 5)

    static func bulkRename(_ urls: [URL]) {
        BulkRenameUI.run(for: urls)
    }

    // MARK: - New Terminal Tab Here (Epic 5)

    /// Scripts iTerm2 if it's installed (a reasonable proxy for "the user
    /// prefers iTerm" — the doc's "detect which is default" without a
    /// dedicated default-terminal API to query), else Terminal.app.
    static func openTerminal(in directory: URL) {
        let iTermInstalled = FileManager.default.fileExists(atPath: "/Applications/iTerm.app")
        let path = directory.path
        let escapedForAppleScript = path.replacingOccurrences(of: "\"", with: "\\\"")

        let source: String
        if iTermInstalled {
            source = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window to create tab with default profile
                end if
                tell current session of current window
                    write text "cd \\"\(escapedForAppleScript)\\""
                end tell
            end tell
            """
        } else {
            source = """
            tell application "Terminal"
                activate
                do script "cd \\"\(escapedForAppleScript)\\""
            end tell
            """
        }

        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            NSLog("CorrectClick: failed to open terminal here: \(error)")
            notify(body: "Couldn't open a terminal here.")
        }
    }

    // MARK: - Helpers

    private static func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private static func notify(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "CorrectClick"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
