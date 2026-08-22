import XCTest

final class FileCreatorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testUniqueURLReturnsBaseNameWhenAvailable() {
        let url = FileCreator.uniqueURL(in: tempDir, stem: "Untitled", ext: "txt")
        XCTAssertEqual(url.lastPathComponent, "Untitled.txt")
    }

    func testUniqueURLIncrementsWhenNameTaken() throws {
        try Data().write(to: tempDir.appendingPathComponent("Untitled.txt"))
        let url = FileCreator.uniqueURL(in: tempDir, stem: "Untitled", ext: "txt")
        XCTAssertEqual(url.lastPathComponent, "Untitled 2.txt")
    }

    func testUniqueURLIncrementsPastMultipleExistingFiles() throws {
        try Data().write(to: tempDir.appendingPathComponent("Untitled.txt"))
        try Data().write(to: tempDir.appendingPathComponent("Untitled 2.txt"))
        let url = FileCreator.uniqueURL(in: tempDir, stem: "Untitled", ext: "txt")
        XCTAssertEqual(url.lastPathComponent, "Untitled 3.txt")
    }

    func testUniqueURLHandlesEmptyExtensionForDotfiles() {
        let url = FileCreator.uniqueURL(in: tempDir, stem: ".gitignore", ext: "")
        XCTAssertEqual(url.lastPathComponent, ".gitignore")
    }

    func testUniqueURLIncrementsExtensionlessNames() throws {
        try Data().write(to: tempDir.appendingPathComponent("LICENSE"))
        let url = FileCreator.uniqueURL(in: tempDir, stem: "LICENSE", ext: "")
        XCTAssertEqual(url.lastPathComponent, "LICENSE 2")
    }

    func testUniqueURLDoesNotCollideAcrossDifferentExtensions() throws {
        try Data().write(to: tempDir.appendingPathComponent("Untitled.txt"))
        let url = FileCreator.uniqueURL(in: tempDir, stem: "Untitled", ext: "json")
        XCTAssertEqual(url.lastPathComponent, "Untitled.json")
    }
}
