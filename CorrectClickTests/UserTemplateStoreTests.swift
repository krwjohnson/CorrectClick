import XCTest

final class UserTemplateStoreTests: XCTestCase {

    private var fileURL: URL!
    private var store: UserTemplateStore!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        store = UserTemplateStore(fileURL: fileURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testLoadWithNoSavedFileReturnsEmpty() {
        XCTAssertEqual(store.load(), [])
    }

    func testSaveThenLoadRoundTrips() {
        let templates = [
            UserTemplate(displayName: "Daily Note", fileExtension: "md", starterContent: "# {{date}}", sortOrder: 0),
            UserTemplate(displayName: "React Component", fileExtension: "tsx", starterContent: "", sortOrder: 1, enabled: false),
        ]
        store.save(templates)

        let reloaded = store.load()
        XCTAssertEqual(reloaded, templates)
    }

    func testEnabledOrderedExcludesDisabledAndSortsByOrder() {
        let a = UserTemplate(displayName: "A", fileExtension: "txt", starterContent: "", sortOrder: 1, enabled: true)
        let b = UserTemplate(displayName: "B", fileExtension: "txt", starterContent: "", sortOrder: 0, enabled: true)
        let c = UserTemplate(displayName: "C", fileExtension: "txt", starterContent: "", sortOrder: 2, enabled: false)

        let ordered = store.enabledOrdered(from: [a, b, c])
        XCTAssertEqual(ordered.map(\.displayName), ["B", "A"])
    }

    func testExportThenImportRoundTripsIdentically() throws {
        // Simulates the Snippets pane's Export button (encode) followed by
        // Import into a fresh install (merge into an empty existing set).
        let originals = [
            UserTemplate(displayName: "Daily Note", fileExtension: "md", starterContent: "# {{date}}", sortOrder: 0),
            UserTemplate(displayName: "Dockerfile Template", fileExtension: "", starterContent: "FROM ", sortOrder: 1),
        ]

        let exportedData = try JSONEncoder().encode(originals)
        let imported = try JSONDecoder().decode([UserTemplate].self, from: exportedData)
        let merged = UserTemplateOperations.merge(existing: [], importing: imported)

        XCTAssertEqual(merged.sorted { $0.sortOrder < $1.sortOrder }, originals)
    }
}
