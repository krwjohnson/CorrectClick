import XCTest

final class TemplateVariableSubstitutionTests: XCTestCase {

    private func fixedContext(
        clipboardText: String? = "clip",
        filenameAtCreation: String? = "Untitled"
    ) -> TemplateContext {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 20
        components.hour = 9
        components.minute = 5
        components.second = 3
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        return TemplateContext(
            date: date,
            author: "Ada Lovelace",
            clipboardText: clipboardText,
            filenameAtCreation: filenameAtCreation
        )
    }

    func testDatePlaceholder() {
        let result = TemplateVariableSubstitution.resolve("{{date}}", context: fixedContext())
        XCTAssertEqual(result, "2026-08-20")
    }

    func testTimePlaceholder() {
        let result = TemplateVariableSubstitution.resolve("{{time}}", context: fixedContext())
        XCTAssertEqual(result, "09:05:03")
    }

    func testDatetimePlaceholderIsISO8601() throws {
        let context = fixedContext()
        let result = TemplateVariableSubstitution.resolve("{{datetime}}", context: context)

        // Match the shape (not a hardcoded offset — the formatter renders
        // in UTC regardless of the test machine's local timezone) and
        // confirm it round-trips back to the same instant.
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#
        XCTAssertNotNil(result.range(of: pattern, options: .regularExpression), "Expected ISO 8601 datetime, got \(result)")

        let parsed = try XCTUnwrap(ISO8601DateFormatter().date(from: result))
        XCTAssertEqual(parsed.timeIntervalSince1970, context.date.timeIntervalSince1970, accuracy: 1)
    }

    func testFilenamePlaceholderUsesCreationTimeStem() {
        let result = TemplateVariableSubstitution.resolve("{{filename}}", context: fixedContext(filenameAtCreation: "Daily Note"))
        XCTAssertEqual(result, "Daily Note")
    }

    func testClipboardPlaceholder() {
        let result = TemplateVariableSubstitution.resolve("{{clipboard}}", context: fixedContext(clipboardText: "hello world"))
        XCTAssertEqual(result, "hello world")
    }

    func testClipboardPlaceholderResolvesToEmptyWhenNoClipboardText() {
        let result = TemplateVariableSubstitution.resolve("{{clipboard}}", context: fixedContext(clipboardText: nil))
        XCTAssertEqual(result, "")
    }

    func testAuthorPlaceholder() {
        let result = TemplateVariableSubstitution.resolve("{{author}}", context: fixedContext())
        XCTAssertEqual(result, "Ada Lovelace")
    }

    func testMultiplePlaceholdersInOneString() {
        let result = TemplateVariableSubstitution.resolve("# {{filename}} — {{date}}\nBy {{author}}", context: fixedContext(filenameAtCreation: "Notes"))
        XCTAssertEqual(result, "# Notes — 2026-08-20\nBy Ada Lovelace")
    }

    func testUnknownPlaceholderIsLeftLiteralAndDoesNotCrash() {
        let result = TemplateVariableSubstitution.resolve("Hello {{nonsense}} world", context: fixedContext())
        XCTAssertEqual(result, "Hello {{nonsense}} world")
    }

    func testMalformedPlaceholderIsLeftLiteral() {
        let result = TemplateVariableSubstitution.resolve("Hello {{date world", context: fixedContext())
        XCTAssertEqual(result, "Hello {{date world")
    }

    func testContentWithNoPlaceholdersIsUnchanged() {
        let result = TemplateVariableSubstitution.resolve("plain text, no placeholders", context: fixedContext())
        XCTAssertEqual(result, "plain text, no placeholders")
    }

    func testEmptyContentDoesNotCrash() {
        let result = TemplateVariableSubstitution.resolve("", context: fixedContext())
        XCTAssertEqual(result, "")
    }

    func testWhitespaceInsidePlaceholderBracesIsTolerated() {
        let result = TemplateVariableSubstitution.resolve("{{ date }}", context: fixedContext())
        XCTAssertEqual(result, "2026-08-20")
    }
}
