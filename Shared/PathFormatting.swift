import Foundation

/// Pure string-formatting helpers for the "Copy … Path" family of actions
/// (Epic 5). Kept separate from clipboard/pasteboard I/O so they're
/// trivially unit-testable — a path with spaces and special characters is
/// exactly the case worth pinning down with a test.
enum PathFormatting {

    static func posixPath(for url: URL) -> String {
        url.path
    }

    /// Shell-escaped for safe pasting into a POSIX shell command line —
    /// wraps in single quotes, escaping any single quote in the path itself
    /// via the standard `'\''` trick (close quote, escaped quote, reopen).
    static func shellEscapedPath(for url: URL) -> String {
        "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func fileURLString(for url: URL) -> String {
        url.absoluteString
    }

    /// `[filename](file:///path)` — the filename is escaped for Markdown's
    /// own special characters so a name like "a[b].txt" doesn't break the
    /// link syntax; the URL itself needs no separate escaping since
    /// `URL.absoluteString` already percent-encodes it.
    static func markdownLink(for url: URL) -> String {
        let name = url.lastPathComponent
        let escapedName = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escapedName)](\(url.absoluteString))"
    }

    /// Joins one formatted line per URL — the multi-selection case for
    /// every "Copy … Path" action.
    static func joined(_ urls: [URL], format: (URL) -> String) -> String {
        urls.map(format).joined(separator: "\n")
    }
}
