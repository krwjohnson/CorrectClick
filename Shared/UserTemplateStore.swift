import Foundation

/// Reads and writes the user-defined templates shared by the app
/// (Preferences window) and the extension (menu building + file creation).
/// Same cross-container rationale as `MenuPreferencesStore` — see that
/// file's doc comment.
final class UserTemplateStore {
    static let shared = UserTemplateStore()

    private let fileURL: URL

    init(fileURL: URL = UserTemplateStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        URL(fileURLWithPath: RealHomeDirectory.path)
            .appendingPathComponent("Library/Application Support/CorrectClick/templates.json")
    }

    func load() -> [UserTemplate] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([UserTemplate].self, from: data)) ?? []
    }

    func save(_ templates: [UserTemplate]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(templates)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("CorrectClick: failed to save user templates: \(error)")
        }
    }

    /// Enabled templates, sorted for menu display — what the Finder menu
    /// should actually show.
    func enabledOrdered(from templates: [UserTemplate]) -> [UserTemplate] {
        templates.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
    }
}
