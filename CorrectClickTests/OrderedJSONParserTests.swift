import XCTest

final class OrderedJSONParserTests: XCTestCase {

    func testParsesObjectPreservingKeyOrder() throws {
        let result = try OrderedJSONParser.parse(#"{"z": 1, "a": 2, "m": 3}"#)
        guard case .object(let pairs) = result else { return XCTFail("expected object") }
        XCTAssertEqual(pairs.map(\.0), ["z", "a", "m"])
    }

    func testParsesArray() throws {
        let result = try OrderedJSONParser.parse("[1, 2, 3]")
        XCTAssertEqual(result, .array([.number("1"), .number("2"), .number("3")]))
    }

    func testParsesStringWithEscapes() throws {
        let result = try OrderedJSONParser.parse(#""line1\nline2\t\"quoted\"""#)
        XCTAssertEqual(result, .string("line1\nline2\t\"quoted\""))
    }

    func testParsesUnicodeEscape() throws {
        let result = try OrderedJSONParser.parse(#""é""#)
        XCTAssertEqual(result, .string("é"))
    }

    func testParsesBooleansAndNull() throws {
        XCTAssertEqual(try OrderedJSONParser.parse("true"), .bool(true))
        XCTAssertEqual(try OrderedJSONParser.parse("false"), .bool(false))
        XCTAssertEqual(try OrderedJSONParser.parse("null"), .null)
    }

    func testParsesNegativeAndDecimalNumbers() throws {
        XCTAssertEqual(try OrderedJSONParser.parse("-42"), .number("-42"))
        XCTAssertEqual(try OrderedJSONParser.parse("3.14"), .number("3.14"))
        XCTAssertEqual(try OrderedJSONParser.parse("1e10"), .number("1e10"))
    }

    func testParsesNestedStructure() throws {
        let result = try OrderedJSONParser.parse(#"{"a": [1, {"b": true}]}"#)
        guard case .object(let pairs) = result, pairs.count == 1, pairs[0].0 == "a" else {
            return XCTFail("expected object with key 'a'")
        }
        guard case .array(let arr) = pairs[0].1, arr.count == 2 else {
            return XCTFail("expected 2-element array")
        }
        XCTAssertEqual(arr[0], .number("1"))
        guard case .object(let inner) = arr[1] else { return XCTFail("expected nested object") }
        XCTAssertEqual(inner.map(\.0), ["b"])
    }

    func testEmptyObjectAndArray() throws {
        XCTAssertEqual(try OrderedJSONParser.parse("{}"), .object([]))
        XCTAssertEqual(try OrderedJSONParser.parse("[]"), .array([]))
    }

    func testTolerantOfWhitespace() throws {
        let result = try OrderedJSONParser.parse("  {  \"a\"  :  1  }  ")
        guard case .object(let pairs) = result else { return XCTFail("expected object") }
        XCTAssertEqual(pairs.map(\.0), ["a"])
    }

    func testUnterminatedObjectThrows() {
        XCTAssertThrowsError(try OrderedJSONParser.parse(#"{"a": 1"#))
    }

    func testUnterminatedStringThrows() {
        XCTAssertThrowsError(try OrderedJSONParser.parse(#""unterminated"#))
    }

    func testTrailingContentThrows() {
        XCTAssertThrowsError(try OrderedJSONParser.parse("{} garbage"))
    }

    func testInvalidLiteralThrows() {
        XCTAssertThrowsError(try OrderedJSONParser.parse("nul"))
    }

    func testDuplicateKeysArePreservedInOrder() throws {
        // Not JSON best-practice input, but shouldn't crash — the caller
        // (CSVJSONConversion) resolves duplicates by taking the last value.
        let result = try OrderedJSONParser.parse(#"{"a": 1, "a": 2}"#)
        guard case .object(let pairs) = result else { return XCTFail("expected object") }
        XCTAssertEqual(pairs.map(\.0), ["a", "a"])
    }
}
