import Foundation

/// What kind of content a clipboard string looks like — used by "New File
/// from Clipboard (Auto-Detect)" (Epic 4) to decide what to create.
enum ClipboardContentKind: Equatable {
    case url(URL)
    case json
    case plainText
}

enum ClipboardContentDetector {

    /// Classifies clipboard text. Order matters: a URL check first (strict —
    /// must have a scheme and host, so "some text: with a colon" doesn't
    /// misfire), then a real JSON parse attempt, else plain text. Never
    /// throws — worst case is `.plainText`, which is always safe to act on.
    static func detect(_ text: String) -> ClipboardContentKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = strictURL(from: trimmed) {
            return .url(url)
        }

        if looksLikeJSON(trimmed) {
            return .json
        }

        return .plainText
    }

    /// `URL(string:)` alone is far too permissive — it happily parses
    /// "hello world" as a relative-reference "URL" with no scheme. Require
    /// an actual scheme + host so only genuine web addresses count.
    private static func strictURL(from text: String) -> URL? {
        guard !text.contains(where: { $0.isWhitespace }) else { return nil }
        guard let components = URLComponents(string: text),
              let scheme = components.scheme, !scheme.isEmpty,
              components.host != nil, !(components.host?.isEmpty ?? true)
        else { return nil }
        return components.url
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        guard let first = text.first, first == "{" || first == "[" else { return false }
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}
