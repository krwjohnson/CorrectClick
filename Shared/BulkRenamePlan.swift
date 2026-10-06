import Foundation

/// One planned rename — computed, not yet applied.
struct BulkRenameItem: Equatable {
    let originalURL: URL
    let newName: String
}

enum BulkRenameMode {
    /// Empty `find` is treated as a no-op (leaves names unchanged) rather
    /// than matching every position, which would otherwise insert `replace`
    /// between every character — never useful, and easy to trigger by
    /// accident with an empty text field.
    case findReplace(find: String, replace: String)
    /// `padding` is the minimum digit count (e.g. 3 → "001"); 0 means no
    /// zero-padding. The file extension is preserved from the original.
    case sequentialNumbering(prefix: String, start: Int, padding: Int)
}

/// Pure rename-planning logic (Epic 5) — no file I/O, so it's fully
/// unit-testable. `FileActions.swift` applies the plan and does the actual
/// `FileManager` moves.
enum BulkRenamePlan {

    static func plan(for urls: [URL], mode: BulkRenameMode) -> [BulkRenameItem] {
        switch mode {
        case .findReplace(let find, let replace):
            return urls.map { url in
                let name = url.lastPathComponent
                let newName = find.isEmpty ? name : name.replacingOccurrences(of: find, with: replace)
                return BulkRenameItem(originalURL: url, newName: newName)
            }

        case .sequentialNumbering(let prefix, let start, let padding):
            return urls.enumerated().map { index, url in
                let number = start + index
                let numberString = padding > 0 ? String(format: "%0\(padding)d", number) : String(number)
                let ext = url.pathExtension
                let base = prefix + numberString
                let newName = ext.isEmpty ? base : "\(base).\(ext)"
                return BulkRenameItem(originalURL: url, newName: newName)
            }
        }
    }

    /// New names that appear more than once in the plan — e.g. a
    /// find/replace pattern that collapses two distinct names into one.
    /// Worth surfacing in the preview before the user commits to applying it.
    static func duplicateNewNames(in items: [BulkRenameItem]) -> Set<String> {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for item in items {
            if !seen.insert(item.newName).inserted {
                duplicates.insert(item.newName)
            }
        }
        return duplicates
    }

    /// Items whose name is actually changing — an unchanged item (e.g. the
    /// find pattern didn't match that particular file) doesn't need a move.
    static func changedItems(in items: [BulkRenameItem]) -> [BulkRenameItem] {
        items.filter { $0.originalURL.lastPathComponent != $0.newName }
    }
}
