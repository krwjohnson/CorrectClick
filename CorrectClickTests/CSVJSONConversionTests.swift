import XCTest

final class CSVJSONConversionTests: XCTestCase {

    // MARK: - CSV -> JSON

    func testSimpleCSVToJSON() throws {
        let csv = "name,age\nAlice,30\nBob,25\n"
        let json = try CSVJSONConversion.csvToJSON(csv)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [["name": "Alice", "age": "30"], ["name": "Bob", "age": "25"]])
    }

    func testCSVWithQuotedFieldContainingComma() throws {
        let csv = "name,address\n\"Doe, Jane\",\"123 Main St\"\n"
        let json = try CSVJSONConversion.csvToJSON(csv)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [["name": "Doe, Jane", "address": "123 Main St"]])
    }

    func testCSVWithEscapedQuoteInField() throws {
        let csv = "quote\n\"She said \"\"hi\"\"\"\n"
        let json = try CSVJSONConversion.csvToJSON(csv)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [["quote": "She said \"hi\""]])
    }

    func testCSVWithNewlineInQuotedField() throws {
        let csv = "note\n\"line one\nline two\"\n"
        let json = try CSVJSONConversion.csvToJSON(csv)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [["note": "line one\nline two"]])
    }

    func testCSVHeaderOnlyProducesEmptyArray() throws {
        let json = try CSVJSONConversion.csvToJSON("name,age\n")
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [])
    }

    func testEmptyCSVThrows() {
        XCTAssertThrowsError(try CSVJSONConversion.csvToJSON(""))
    }

    func testShortRowFillsMissingColumnsWithEmptyString() throws {
        let csv = "a,b,c\n1,2\n"
        let json = try CSVJSONConversion.csvToJSON(csv)
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(parsed, [["a": "1", "b": "2", "c": ""]])
    }

    // MARK: - JSON -> CSV

    func testSimpleJSONToCSV() throws {
        let json = #"[{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]"#
        let csv = try CSVJSONConversion.jsonToCSV(json)
        XCTAssertEqual(csv, "name,age\r\nAlice,30\r\nBob,25\r\n")
    }

    func testJSONToCSVEscapesFieldsWithCommas() throws {
        let json = #"[{"note": "hello, world"}]"#
        let csv = try CSVJSONConversion.jsonToCSV(json)
        XCTAssertEqual(csv, "note\r\n\"hello, world\"\r\n")
    }

    func testJSONToCSVHandlesBoolAndNull() throws {
        let json = #"[{"active": true, "deleted": false, "notes": null}]"#
        let csv = try CSVJSONConversion.jsonToCSV(json)
        XCTAssertEqual(csv, "active,deleted,notes\r\ntrue,false,\r\n")
    }

    func testJSONToCSVUnionsKeysAcrossObjects() throws {
        let json = #"[{"a": 1}, {"a": 2, "b": 3}]"#
        let csv = try CSVJSONConversion.jsonToCSV(json)
        XCTAssertEqual(csv, "a,b\r\n1,\r\n2,3\r\n")
    }

    func testJSONToCSVEmptyArrayProducesEmptyString() throws {
        XCTAssertEqual(try CSVJSONConversion.jsonToCSV("[]"), "")
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try CSVJSONConversion.jsonToCSV("{not valid json")) { error in
            XCTAssertTrue(error is CSVJSONConversionError)
        }
    }

    func testJSONNotArrayThrows() {
        XCTAssertThrowsError(try CSVJSONConversion.jsonToCSV(#"{"a": 1}"#)) { error in
            guard case CSVJSONConversionError.jsonNotFlatArrayOfObjects = error else {
                return XCTFail("expected jsonNotFlatArrayOfObjects, got \(error)")
            }
        }
    }

    func testJSONWithNestedObjectThrows() {
        XCTAssertThrowsError(try CSVJSONConversion.jsonToCSV(#"[{"a": {"nested": true}}]"#)) { error in
            guard case CSVJSONConversionError.jsonNotFlatArrayOfObjects = error else {
                return XCTFail("expected jsonNotFlatArrayOfObjects, got \(error)")
            }
        }
    }

    // MARK: - Round-trip

    func testRoundTripCSVToJSONToCSV() throws {
        let original = "name,age\nAlice,30\nBob,25\n"
        let json = try CSVJSONConversion.csvToJSON(original)
        let backToCSV = try CSVJSONConversion.jsonToCSV(json)
        XCTAssertEqual(backToCSV, "name,age\r\nAlice,30\r\nBob,25\r\n")
    }
}
