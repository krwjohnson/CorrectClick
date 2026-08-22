import Foundation

/// The `{{author}}` name, set once in Preferences (Epic 2). Same
/// cross-container storage rationale as `MenuPreferencesStore` — plain
/// text rather than JSON since it's a single value.
enum AuthorPreferenceStore {
    static var fileURL: URL {
        URL(fileURLWithPath: RealHomeDirectory.path)
            .appendingPathComponent("Library/Application Support/CorrectClick/author.txt")
    }

    static func load() -> String {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
        return contents.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func save(_ name: String) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try name.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("CorrectClick: failed to save author preference: \(error)")
        }
    }
}
