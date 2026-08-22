import Foundation
#if canImport(Darwin)
import Darwin
#endif

// Shared between the CorrectClick app (Preferences window) and
// CorrectClickExtension (Finder menu building). Compiled into both targets
// directly (see project.yml) rather than a framework, so it must stay
// Foundation-only — no AppKit.

/// Which section of the CorrectClick submenu an item belongs to. The two
/// sections stay visually separated by a divider; items can be reordered
/// within a section but not across the divider.
enum MenuItemCategory: String, Codable {
    case create
    case clipboard
}

/// Static description of one built-in menu action. `id` is persisted in
/// preferences.json, so it must stay stable across releases — never rename
/// or reuse an id, only append new ones.
struct MenuItemDefinition {
    let id: String
    let category: MenuItemCategory
    let title: String
}

enum BuiltInMenuItems {
    /// Canonical list and default order of every built-in action. New
    /// built-in types must be appended at the end of their section so
    /// existing users' saved order/enabled state for earlier items is
    /// undisturbed (see `MenuPreferencesStore.load`).
    static let all: [MenuItemDefinition] = [
        MenuItemDefinition(id: "text", category: .create, title: "New Text File"),
        MenuItemDefinition(id: "json", category: .create, title: "New JSON File"),
        MenuItemDefinition(id: "python", category: .create, title: "New Python File"),
        MenuItemDefinition(id: "csv", category: .create, title: "New CSV File"),
        MenuItemDefinition(id: "markdown", category: .create, title: "New Markdown File"),
        MenuItemDefinition(id: "shell", category: .create, title: "New Shell Script"),
        MenuItemDefinition(id: "yaml", category: .create, title: "New YAML File"),
        MenuItemDefinition(id: "html", category: .create, title: "New HTML File"),
        // Epic 1 additions:
        MenuItemDefinition(id: "toml", category: .create, title: "New TOML File"),
        MenuItemDefinition(id: "xml", category: .create, title: "New XML File"),
        MenuItemDefinition(id: "gitignore", category: .create, title: "New .gitignore File"),
        MenuItemDefinition(id: "license", category: .create, title: "New LICENSE File"),
        MenuItemDefinition(id: "env", category: .create, title: "New .env File"),
        MenuItemDefinition(id: "dockerfile", category: .create, title: "New Dockerfile"),
        MenuItemDefinition(id: "swift", category: .create, title: "New Swift File"),
        MenuItemDefinition(id: "sql", category: .create, title: "New SQL File"),
        MenuItemDefinition(id: "plist", category: .create, title: "New .plist File"),

        MenuItemDefinition(id: "textFromClipboard", category: .clipboard, title: "New Text File from Clipboard"),
        MenuItemDefinition(id: "pngFromClipboard", category: .clipboard, title: "New PNG from Clipboard"),
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

/// One item's persisted state: whether it's shown, and its position within
/// its category.
struct MenuItemState: Codable, Equatable {
    var id: String
    var enabled: Bool
    var sortIndex: Int
}

/// Reads and writes the preferences file shared by the app and the
/// extension. They run in different sandbox containers, so this can't live
/// in either one's own container — it's written to a real, absolute path
/// outside both. That requires a `temporary-exception.files` entitlement
/// scoped to this one folder on the app side (the extension already holds a
/// blanket filesystem exception for file creation).
final class MenuPreferencesStore {
    static let shared = MenuPreferencesStore()

    private let fileURL: URL

    init(fileURL: URL = MenuPreferencesStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        URL(fileURLWithPath: RealHomeDirectory.path)
            .appendingPathComponent("Library/Application Support/CorrectClick/preferences.json")
    }

    /// Loads saved state merged with the current built-in registry: any item
    /// missing from the saved file (new install, or a type added in a later
    /// release) defaults to enabled, appended after the existing items in
    /// its category so it doesn't disturb the user's saved order. Any saved
    /// id no longer in the registry is silently dropped.
    func load() -> [MenuItemState] {
        let saved = loadFromDisk()

        // Defend against a corrupted/hand-edited file with duplicate ids —
        // a crashing Finder Sync Extension can take Finder down with it, so
        // this must never trap.
        var byID: [String: MenuItemState] = [:]
        for state in saved {
            byID[state.id] = state
        }

        var maxIndexByCategory: [MenuItemCategory: Int] = [:]
        for state in saved {
            guard let category = BuiltInMenuItems.byID[state.id]?.category else { continue }
            maxIndexByCategory[category] = max(maxIndexByCategory[category] ?? -1, state.sortIndex)
        }

        for item in BuiltInMenuItems.all where byID[item.id] == nil {
            let nextIndex = (maxIndexByCategory[item.category] ?? -1) + 1
            maxIndexByCategory[item.category] = nextIndex
            byID[item.id] = MenuItemState(id: item.id, enabled: true, sortIndex: nextIndex)
        }

        return BuiltInMenuItems.all.compactMap { byID[$0.id] }
    }

    func save(_ states: [MenuItemState]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(states)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("CorrectClick: failed to save menu preferences: \(error)")
        }
    }

    /// Definitions in `category`, in display order, paired with their state.
    func orderedItems(in category: MenuItemCategory, from states: [MenuItemState]) -> [(MenuItemDefinition, MenuItemState)] {
        states
            .filter { BuiltInMenuItems.byID[$0.id]?.category == category }
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { state in BuiltInMenuItems.byID[state.id].map { ($0, state) } }
    }

    /// Enabled definitions in `category`, in display order — what the
    /// Finder menu should actually show.
    func enabledOrderedItems(in category: MenuItemCategory, from states: [MenuItemState]) -> [MenuItemDefinition] {
        orderedItems(in: category, from: states)
            .filter { $0.1.enabled }
            .map { $0.0 }
    }

    private func loadFromDisk() -> [MenuItemState] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([MenuItemState].self, from: data)) ?? []
    }
}

/// The user's true home directory, unaffected by App Sandbox container
/// remapping. `NSHomeDirectory()` / `FileManager.default.homeDirectoryForCurrentUser`
/// both report the sandbox container path even when a temporary-exception
/// entitlement grants access outside it — this reads the real path from the
/// system user database instead, so the app and extension (which each have
/// their own container) agree on the same absolute file location.
enum RealHomeDirectory {
    static var path: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory() // Fallback; shouldn't happen.
    }
}
