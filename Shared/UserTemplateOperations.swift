import Foundation

/// Pure CRUD helpers over a `[UserTemplate]` array — kept separate from
/// `UserTemplateStore` so they're trivially unit-testable without touching
/// disk, and reusable from both the Preferences UI and import/export.
enum UserTemplateOperations {

    static func add(_ template: UserTemplate, to templates: [UserTemplate]) -> [UserTemplate] {
        templates + [template]
    }

    static func update(_ template: UserTemplate, in templates: [UserTemplate]) -> [UserTemplate] {
        var copy = templates
        if let index = copy.firstIndex(where: { $0.id == template.id }) {
            copy[index] = template
        }
        return copy
    }

    static func delete(id: UUID, from templates: [UserTemplate]) -> [UserTemplate] {
        templates.filter { $0.id != id }
    }

    static func setEnabled(_ enabled: Bool, id: UUID, in templates: [UserTemplate]) -> [UserTemplate] {
        var copy = templates
        if let index = copy.firstIndex(where: { $0.id == id }) {
            copy[index].enabled = enabled
        }
        return copy
    }

    /// Reindexes `sortOrder` to match the order of `templates` as given
    /// (0, 1, 2, …) — call after reordering in the UI, before persisting.
    static func reindexed(_ templates: [UserTemplate]) -> [UserTemplate] {
        templates.enumerated().map { index, template in
            var template = template
            template.sortOrder = index
            return template
        }
    }

    /// Merges an imported set into an existing one for the Import action:
    /// an imported template whose id already exists locally overwrites it
    /// in place; a new id is appended after the existing templates. Used so
    /// re-importing a previously-exported file is idempotent, while a fresh
    /// import into an empty set reproduces exactly what was exported.
    static func merge(existing: [UserTemplate], importing: [UserTemplate]) -> [UserTemplate] {
        var byID: [UUID: UserTemplate] = [:]
        for template in existing {
            byID[template.id] = template
        }

        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        for template in importing {
            if byID[template.id] != nil {
                byID[template.id] = template
            } else {
                var template = template
                template.sortOrder = nextOrder
                nextOrder += 1
                byID[template.id] = template
            }
        }

        return byID.values.sorted { $0.sortOrder < $1.sortOrder }
    }
}
