import Foundation

/// Values available for `{{placeholder}}` substitution in a template's
/// starter content.
struct TemplateContext {
    var date: Date = Date()
    /// `DateFormatter`-syntax format for `{{date}}`. Defaults to the
    /// requirements doc's default (written as `YYYY-MM-DD` there; that's
    /// `yyyy-MM-dd` in `DateFormatter` syntax).
    var dateFormat: String = "yyyy-MM-dd"
    var timeFormat: String = "HH:mm:ss"
    var author: String = ""
    /// Current clipboard text, if any. Resolves to "" when there's no
    /// text on the clipboard — only genuinely *unknown* placeholders are
    /// left as literal text (see `TemplateVariableSubstitution`).
    var clipboardText: String?
    /// The auto-generated stem the file is about to be created with (e.g.
    /// "Untitled 2"), **not** the name the user eventually renames it to.
    ///
    /// Finder Sync extensions have no API to observe when an interactive
    /// Finder rename completes, so the true final filename can't be known
    /// at content-write time — this is a documented limitation (see the
    /// Epic 2 note in CLAUDE.md), not something left unfinished by mistake.
    var filenameAtCreation: String?

    init(
        date: Date = Date(),
        dateFormat: String = "yyyy-MM-dd",
        timeFormat: String = "HH:mm:ss",
        author: String = "",
        clipboardText: String? = nil,
        filenameAtCreation: String? = nil
    ) {
        self.date = date
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
        self.author = author
        self.clipboardText = clipboardText
        self.filenameAtCreation = filenameAtCreation
    }
}

enum TemplateVariableSubstitution {

    private static let supportedPlaceholders: Set<String> = [
        "date", "time", "datetime", "filename", "clipboard", "author",
    ]

    // Force-try is safe here: the pattern is a fixed, valid literal.
    private static let pattern = try! NSRegularExpression(pattern: #"\{\{\s*(\w+)\s*\}\}"#)

    /// Replaces every *supported* `{{placeholder}}` in `content` with its
    /// resolved value from `context`. A placeholder outside the supported
    /// set — a typo, or one the user made up — is left exactly as written:
    /// never stripped, never a crash, per the requirements doc.
    static func resolve(_ content: String, context: TemplateContext) -> String {
        let nsContent = content as NSString
        let matches = pattern.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        guard !matches.isEmpty else { return content }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let fullRange = match.range
            let nameRange = match.range(at: 1)
            guard fullRange.location != NSNotFound, nameRange.location != NSNotFound else { continue }

            result += nsContent.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))

            let name = nsContent.substring(with: nameRange)
            result += resolvedValue(for: name, context: context) ?? nsContent.substring(with: fullRange)

            lastEnd = fullRange.location + fullRange.length
        }
        result += nsContent.substring(from: lastEnd)
        return result
    }

    /// Returns the resolved value for a supported placeholder name, or nil
    /// for an unsupported one (meaning: leave the original text alone).
    private static func resolvedValue(for name: String, context: TemplateContext) -> String? {
        guard supportedPlaceholders.contains(name) else { return nil }
        switch name {
        case "date":
            return formatter(context.dateFormat).string(from: context.date)
        case "time":
            return formatter(context.timeFormat).string(from: context.date)
        case "datetime":
            return isoFormatter.string(from: context.date)
        case "filename":
            return context.filenameAtCreation ?? ""
        case "clipboard":
            return context.clipboardText ?? ""
        case "author":
            return context.author
        default:
            return nil
        }
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
