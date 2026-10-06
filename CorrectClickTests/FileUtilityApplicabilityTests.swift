import XCTest

final class FileUtilityApplicabilityTests: XCTestCase {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testNewTerminalHereAlwaysApplicable() {
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "newTerminalHere", selection: []))
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "newTerminalHere", selection: [url("a.txt")]))
    }

    func testPathCopyActionsNeedAtLeastOneSelectedItem() {
        for id in ["copyPOSIXPath", "copyShellEscapedPath", "copyFileURL", "copyMarkdownLink"] {
            XCTAssertFalse(FileUtilityApplicability.isApplicable(id: id, selection: []), id)
            XCTAssertTrue(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt")]), id)
            XCTAssertTrue(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt"), url("b.txt")]), id)
        }
    }

    func testBase64AndHashNeedExactlyOneSelectedItem() {
        for id in ["copyBase64", "generateHash"] {
            XCTAssertFalse(FileUtilityApplicability.isApplicable(id: id, selection: []), id)
            XCTAssertTrue(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt")]), id)
            XCTAssertFalse(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt"), url("b.txt")]), id)
        }
    }

    func testCompressAndBulkRenameNeedAtLeastOneSelectedItem() {
        for id in ["compressToZip", "bulkRename"] {
            XCTAssertFalse(FileUtilityApplicability.isApplicable(id: id, selection: []), id)
            XCTAssertTrue(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt")]), id)
            XCTAssertTrue(FileUtilityApplicability.isApplicable(id: id, selection: [url("a.txt"), url("b.txt")]), id)
        }
    }

    func testExtractZipNeedsExactlyOneSelectedZipFile() {
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "extractZip", selection: [url("archive.zip")]))
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "extractZip", selection: [url("archive.ZIP")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "extractZip", selection: [url("archive.tar.gz")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "extractZip", selection: []))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "extractZip", selection: [url("a.zip"), url("b.zip")]))
    }

    func testCSVToJSONNeedsExactlyOneSelectedCSVFile() {
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "csvToJSON", selection: [url("data.csv")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "csvToJSON", selection: [url("data.json")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "csvToJSON", selection: []))
    }

    func testJSONToCSVNeedsExactlyOneSelectedJSONFile() {
        XCTAssertTrue(FileUtilityApplicability.isApplicable(id: "jsonToCSV", selection: [url("data.json")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "jsonToCSV", selection: [url("data.csv")]))
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "jsonToCSV", selection: []))
    }

    func testUnknownIDFailsClosed() {
        XCTAssertFalse(FileUtilityApplicability.isApplicable(id: "somethingMadeUp", selection: [url("a.txt")]))
    }
}
