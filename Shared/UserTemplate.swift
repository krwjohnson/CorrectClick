import Foundation

/// A user-defined "New [X] File" menu entry (Epic 2). Foundation-only —
/// compiled into the app, the extension, and the test target (see
/// Shared/MenuItemPreferences.swift for why).
struct UserTemplate: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    /// No leading dot; empty string means no extension (e.g. a "Dockerfile"
    /// style template). Use `normalizedExtension` rather than this raw
    /// value when creating a file — it tolerates a user typing ".txt".
    var fileExtension: String
    var starterContent: String
    var sortOrder: Int
    var enabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        fileExtension: String,
        starterContent: String,
        sortOrder: Int,
        enabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.starterContent = starterContent
        self.sortOrder = sortOrder
        self.enabled = enabled
        self.createdAt = createdAt
    }

    var normalizedExtension: String {
        fileExtension.hasPrefix(".") ? String(fileExtension.dropFirst()) : fileExtension
    }

    /// The "Untitled"-equivalent stem used when creating a file from this
    /// template — derived from the display name (with a leading "New "
    /// stripped, matching the built-in naming style) rather than always
    /// "Untitled", since a custom template's name is usually the point.
    var fileNameStem: String {
        var name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("New ") {
            name = String(name.dropFirst(4))
        }
        return name.isEmpty ? "Untitled" : name
    }
}
