import XCTest

final class PathFormattingTests: XCTestCase {

    private let plainURL = URL(fileURLWithPath: "/Users/jane/Documents/report.txt")
    private let spacedURL = URL(fileURLWithPath: "/Users/jane/My Documents/final report.txt")
    private let quoteURL = URL(fileURLWithPath: "/Users/jane/it's a file.txt")

    func testPOSIXPath() {
        XCTAssertEqual(PathFormatting.posixPath(for: plainURL), "/Users/jane/Documents/report.txt")
    }

    func testPOSIXPathWithSpaces() {
        XCTAssertEqual(PathFormatting.posixPath(for: spacedURL), "/Users/jane/My Documents/final report.txt")
    }

    func testShellEscapedPathWrapsInSingleQuotes() {
        XCTAssertEqual(PathFormatting.shellEscapedPath(for: spacedURL), "'/Users/jane/My Documents/final report.txt'")
    }

    func testShellEscapedPathEscapesEmbeddedSingleQuote() {
        XCTAssertEqual(PathFormatting.shellEscapedPath(for: quoteURL), "'/Users/jane/it'\\''s a file.txt'")
    }

    func testFileURLString() {
        XCTAssertEqual(PathFormatting.fileURLString(for: plainURL), "file:///Users/jane/Documents/report.txt")
    }

    func testFileURLStringWithSpacesIsPercentEncoded() {
        XCTAssertEqual(
            PathFormatting.fileURLString(for: spacedURL),
            "file:///Users/jane/My%20Documents/final%20report.txt"
        )
    }

    func testMarkdownLink() {
        XCTAssertEqual(
            PathFormatting.markdownLink(for: plainURL),
            "[report.txt](file:///Users/jane/Documents/report.txt)"
        )
    }

    func testMarkdownLinkEscapesBracketsInFilename() {
        let url = URL(fileURLWithPath: "/tmp/notes [draft].txt")
        let result = PathFormatting.markdownLink(for: url)
        XCTAssertTrue(result.hasPrefix("[notes \\[draft\\].txt]("), result)
    }

    func testJoinedMultipleURLs() {
        let result = PathFormatting.joined([plainURL, spacedURL], format: PathFormatting.posixPath)
        XCTAssertEqual(result, "/Users/jane/Documents/report.txt\n/Users/jane/My Documents/final report.txt")
    }

    func testJoinedSingleURL() {
        let result = PathFormatting.joined([plainURL], format: PathFormatting.posixPath)
        XCTAssertEqual(result, "/Users/jane/Documents/report.txt")
    }
}
