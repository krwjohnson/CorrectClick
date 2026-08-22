import XCTest

final class UserTemplateOperationsTests: XCTestCase {

    private func makeTemplate(_ name: String, sortOrder: Int = 0, enabled: Bool = true) -> UserTemplate {
        UserTemplate(displayName: name, fileExtension: "txt", starterContent: "", sortOrder: sortOrder, enabled: enabled)
    }

    func testAddAppendsTemplate() {
        let existing = [makeTemplate("A")]
        let result = UserTemplateOperations.add(makeTemplate("B"), to: existing)
        XCTAssertEqual(result.map(\.displayName), ["A", "B"])
    }

    func testUpdateReplacesMatchingID() {
        var template = makeTemplate("A")
        let existing = [template]
        template.displayName = "A renamed"
        let result = UserTemplateOperations.update(template, in: existing)
        XCTAssertEqual(result.first?.displayName, "A renamed")
        XCTAssertEqual(result.count, 1)
    }

    func testUpdateWithUnknownIDIsANoOp() {
        let existing = [makeTemplate("A")]
        let unrelated = makeTemplate("Ghost")
        let result = UserTemplateOperations.update(unrelated, in: existing)
        XCTAssertEqual(result, existing)
    }

    func testDeleteRemovesMatchingID() {
        let a = makeTemplate("A")
        let b = makeTemplate("B")
        let result = UserTemplateOperations.delete(id: a.id, from: [a, b])
        XCTAssertEqual(result.map(\.displayName), ["B"])
    }

    func testSetEnabledTogglesOnlyMatchingID() {
        let a = makeTemplate("A", enabled: true)
        let b = makeTemplate("B", enabled: true)
        let result = UserTemplateOperations.setEnabled(false, id: a.id, in: [a, b])
        XCTAssertEqual(result.first { $0.id == a.id }?.enabled, false)
        XCTAssertEqual(result.first { $0.id == b.id }?.enabled, true)
    }

    func testReindexedAssignsSequentialSortOrder() {
        let templates = [makeTemplate("A", sortOrder: 9), makeTemplate("B", sortOrder: 2)]
        let result = UserTemplateOperations.reindexed(templates)
        XCTAssertEqual(result.map(\.sortOrder), [0, 1])
    }

    func testMergeIntoEmptyReproducesImportedSet() {
        let imported = [makeTemplate("A", sortOrder: 0), makeTemplate("B", sortOrder: 1)]
        let result = UserTemplateOperations.merge(existing: [], importing: imported)
        XCTAssertEqual(Set(result.map(\.id)), Set(imported.map(\.id)))
        XCTAssertEqual(result.sorted { $0.sortOrder < $1.sortOrder }.map(\.displayName), ["A", "B"])
    }

    func testMergeOverwritesExistingIDAndAppendsNewOnes() {
        let existing = makeTemplate("Original", sortOrder: 0)
        var updated = existing
        updated.displayName = "Updated"
        let newTemplate = makeTemplate("Newcomer", sortOrder: 0)

        let result = UserTemplateOperations.merge(existing: [existing], importing: [updated, newTemplate])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.id == existing.id }?.displayName, "Updated")
        XCTAssertTrue(result.contains { $0.id == newTemplate.id })
    }
}
