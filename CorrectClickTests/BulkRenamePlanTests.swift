import XCTest

final class BulkRenamePlanTests: XCTestCase {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testFindReplace() {
        let items = BulkRenamePlan.plan(
            for: [url("vacation-photo-1.jpg"), url("vacation-photo-2.jpg")],
            mode: .findReplace(find: "vacation-photo", replace: "beach")
        )
        XCTAssertEqual(items.map(\.newName), ["beach-1.jpg", "beach-2.jpg"])
    }

    func testFindReplaceWithEmptyFindIsANoOp() {
        let items = BulkRenamePlan.plan(for: [url("a.txt")], mode: .findReplace(find: "", replace: "x"))
        XCTAssertEqual(items.map(\.newName), ["a.txt"])
    }

    func testFindReplaceWithNoMatchLeavesNameUnchanged() {
        let items = BulkRenamePlan.plan(for: [url("a.txt")], mode: .findReplace(find: "zzz", replace: "x"))
        XCTAssertEqual(items.map(\.newName), ["a.txt"])
    }

    func testSequentialNumberingPreservesExtension() {
        let items = BulkRenamePlan.plan(
            for: [url("img1.png"), url("img2.png"), url("img3.png")],
            mode: .sequentialNumbering(prefix: "Photo ", start: 1, padding: 0)
        )
        XCTAssertEqual(items.map(\.newName), ["Photo 1.png", "Photo 2.png", "Photo 3.png"])
    }

    func testSequentialNumberingWithPadding() {
        let items = BulkRenamePlan.plan(
            for: [url("a.txt"), url("b.txt")],
            mode: .sequentialNumbering(prefix: "File ", start: 1, padding: 3)
        )
        XCTAssertEqual(items.map(\.newName), ["File 001.txt", "File 002.txt"])
    }

    func testSequentialNumberingWithCustomStart() {
        let items = BulkRenamePlan.plan(
            for: [url("a.txt"), url("b.txt")],
            mode: .sequentialNumbering(prefix: "Item ", start: 10, padding: 0)
        )
        XCTAssertEqual(items.map(\.newName), ["Item 10.txt", "Item 11.txt"])
    }

    func testSequentialNumberingWithNoExtension() {
        let items = BulkRenamePlan.plan(for: [url("Dockerfile")], mode: .sequentialNumbering(prefix: "File ", start: 1, padding: 0))
        XCTAssertEqual(items.map(\.newName), ["File 1"])
    }

    func testDuplicateNewNamesDetected() {
        let items = BulkRenamePlan.plan(
            for: [url("a-1.txt"), url("a-2.txt")],
            mode: .findReplace(find: "-1", replace: "")
        )
        // "a-1.txt" -> "a.txt"; "a-2.txt" -> unchanged "a-2.txt" (no match) — not a collision.
        XCTAssertTrue(BulkRenamePlan.duplicateNewNames(in: items).isEmpty)

        let colliding = BulkRenamePlan.plan(
            for: [url("a-1.txt"), url("a-2.txt")],
            mode: .findReplace(find: "-1", replace: "-2")
        )
        XCTAssertEqual(BulkRenamePlan.duplicateNewNames(in: colliding), ["a-2.txt"])
    }

    func testChangedItemsExcludesUnchangedNames() {
        let items = BulkRenamePlan.plan(
            for: [url("report.txt"), url("other.csv")],
            mode: .findReplace(find: "report", replace: "summary")
        )
        let changed = BulkRenamePlan.changedItems(in: items)
        XCTAssertEqual(changed.map { $0.originalURL.lastPathComponent }, ["report.txt"])
    }
}
