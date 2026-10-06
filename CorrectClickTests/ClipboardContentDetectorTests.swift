import XCTest

final class ClipboardContentDetectorTests: XCTestCase {

    // MARK: - URLs (5+ representative inputs)

    func testDetectsHTTPSURL() {
        guard case .url(let url) = ClipboardContentDetector.detect("https://example.com/page") else {
            return XCTFail("expected .url")
        }
        XCTAssertEqual(url.host, "example.com")
    }

    func testDetectsHTTPURL() {
        guard case .url = ClipboardContentDetector.detect("http://example.com") else {
            return XCTFail("expected .url")
        }
    }

    func testDetectsURLWithQueryAndFragment() {
        guard case .url = ClipboardContentDetector.detect("https://example.com/search?q=hello#top") else {
            return XCTFail("expected .url")
        }
    }

    func testDetectsFTPURL() {
        guard case .url = ClipboardContentDetector.detect("ftp://files.example.com/archive.zip") else {
            return XCTFail("expected .url")
        }
    }

    func testDetectsURLWithWhitespaceTrimmed() {
        guard case .url = ClipboardContentDetector.detect("  https://example.com  \n") else {
            return XCTFail("expected .url")
        }
    }

    func testTextWithColonIsNotMisdetectedAsURL() {
        let result = ClipboardContentDetector.detect("Note: buy milk")
        XCTAssertEqual(result, .plainText)
    }

    func testTextWithInternalSpacesIsNotAURL() {
        let result = ClipboardContentDetector.detect("https://example.com but also some text")
        XCTAssertEqual(result, .plainText)
    }

    // MARK: - JSON (5+ representative inputs)

    func testDetectsJSONObject() {
        XCTAssertEqual(ClipboardContentDetector.detect(#"{"a": 1}"#), .json)
    }

    func testDetectsJSONArray() {
        XCTAssertEqual(ClipboardContentDetector.detect("[1, 2, 3]"), .json)
    }

    func testDetectsNestedJSON() {
        XCTAssertEqual(ClipboardContentDetector.detect(#"{"a": {"b": [1, 2]}}"#), .json)
    }

    func testDetectsEmptyJSONObject() {
        XCTAssertEqual(ClipboardContentDetector.detect("{}"), .json)
    }

    func testDetectsJSONArrayOfObjects() {
        XCTAssertEqual(ClipboardContentDetector.detect(#"[{"name": "a"}, {"name": "b"}]"#), .json)
    }

    func testMalformedJSONIsNotDetectedAsJSON() {
        XCTAssertEqual(ClipboardContentDetector.detect(#"{"a": 1"#), .plainText)
    }

    // MARK: - Plain text (5+ representative inputs)

    func testDetectsPlainSentence() {
        XCTAssertEqual(ClipboardContentDetector.detect("Hello, world!"), .plainText)
    }

    func testDetectsMultilinePlainText() {
        XCTAssertEqual(ClipboardContentDetector.detect("line one\nline two\nline three"), .plainText)
    }

    func testDetectsNumericText() {
        XCTAssertEqual(ClipboardContentDetector.detect("12345"), .plainText)
    }

    func testDetectsEmptyString() {
        XCTAssertEqual(ClipboardContentDetector.detect(""), .plainText)
    }

    func testDetectsCodeSnippetAsPlainText() {
        XCTAssertEqual(ClipboardContentDetector.detect("let x = 5\nprint(x)"), .plainText)
    }
}
