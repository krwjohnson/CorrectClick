import Foundation

/// Whether a `.fileUtility` menu item makes sense for the current Finder
/// selection — on top of just being enabled in preferences. Pure and
/// selection-only, so it's unit-testable without a live Finder Sync
/// environment; `FinderSync.swift` just calls in with the real selection.
enum FileUtilityApplicability {
    static func isApplicable(id: String, selection: [URL]) -> Bool {
        switch id {
        case "newTerminalHere":
            return true // Target-directory based, like the New File actions — no selection needed.
        case "copyPOSIXPath", "copyShellEscapedPath", "copyFileURL", "copyMarkdownLink", "compressToZip", "bulkRename":
            return !selection.isEmpty
        case "copyBase64", "generateHash":
            return selection.count == 1
        case "extractZip":
            return selection.count == 1 && selection[0].pathExtension.lowercased() == "zip"
        case "csvToJSON":
            return selection.count == 1 && selection[0].pathExtension.lowercased() == "csv"
        case "jsonToCSV":
            return selection.count == 1 && selection[0].pathExtension.lowercased() == "json"
        default:
            return false // An id in the .fileUtility category with no case above is a bug — fail closed, not open.
        }
    }
}
