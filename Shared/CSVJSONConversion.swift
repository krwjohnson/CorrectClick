import Foundation

enum CSVJSONConversionError: Error, LocalizedError {
    case emptyCSV
    case malformedCSV(String)
    case malformedJSON(String)
    case jsonNotFlatArrayOfObjects(String)

    var errorDescription: String? {
        switch self {
        case .emptyCSV:
            return "The CSV file has no header row."
        case .malformedCSV(let detail):
            return "Couldn't parse CSV: \(detail)"
        case .malformedJSON(let detail):
            return "Couldn't parse JSON: \(detail)"
        case .jsonNotFlatArrayOfObjects(let detail):
            return "JSON must be a flat array of objects (no nested objects/arrays): \(detail)"
        }
    }
}

/// CSV ↔ JSON conversion (Epic 6). Pure string-in, string-out — no file
/// I/O, no UI — so it's fully unit-testable, per the requirements doc's
/// explicit call for tests on this kind of parsing/conversion logic.
enum CSVJSONConversion {

    // MARK: - CSV -> JSON

    static func csvToJSON(_ csv: String) throws -> String {
        let rows = try parseCSV(csv)
        guard let header = rows.first, !header.isEmpty else {
            throw CSVJSONConversionError.emptyCSV
        }
        let dataRows = rows.dropFirst()

        var objectLines: [String] = []
        for row in dataRows {
            let fields = header.enumerated().map { index, key -> String in
                let value = index < row.count ? row[index] : ""
                return "\(jsonStringLiteral(key)): \(jsonStringLiteral(value))"
            }
            objectLines.append("  {\n    " + fields.joined(separator: ",\n    ") + "\n  }")
        }

        if objectLines.isEmpty {
            return "[]\n"
        }
        return "[\n" + objectLines.joined(separator: ",\n") + "\n]\n"
    }

    /// RFC 4180-ish parser: handles quoted fields containing commas,
    /// newlines, and escaped ("") quotes. Every row is padded/read as-is —
    /// short rows are handled by the caller (missing columns become "").
    private static func parseCSV(_ csv: String) throws -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(csv)
        var i = 0
        while i < chars.count {
            let char = chars[i]

            if inQuotes {
                if char == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                case "\r":
                    break // Swallow bare CR / the CR of a CRLF; LF handles the row break.
                default:
                    currentField.append(char)
                }
            }
            i += 1
        }

        if inQuotes {
            throw CSVJSONConversionError.malformedCSV("unterminated quoted field")
        }

        // Flush the last field/row if the file doesn't end with a newline.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) } // drop trailing blank lines
    }

    // MARK: - JSON -> CSV

    static func jsonToCSV(_ json: String) throws -> String {
        let value: OrderedJSONValue
        do {
            value = try OrderedJSONParser.parse(json)
        } catch {
            throw CSVJSONConversionError.malformedJSON(error.localizedDescription)
        }

        guard case .array(let elements) = value else {
            throw CSVJSONConversionError.jsonNotFlatArrayOfObjects("top level must be an array of objects")
        }
        let objects = try elements.map { element -> [(String, OrderedJSONValue)] in
            guard case .object(let pairs) = element else {
                throw CSVJSONConversionError.jsonNotFlatArrayOfObjects("every array element must be an object")
            }
            return pairs
        }

        if objects.isEmpty {
            return ""
        }

        // Column order: first-seen order across all objects (in their
        // original JSON key order, not an arbitrary dictionary order), not
        // just the first object — handles objects with slightly differing
        // key sets.
        var header: [String] = []
        var seen = Set<String>()
        for object in objects {
            for (key, _) in object where !seen.contains(key) {
                seen.insert(key)
                header.append(key)
            }
        }

        var lines = [header.map(csvField).joined(separator: ",")]
        for object in objects {
            let byKey = Dictionary(object, uniquingKeysWith: { _, last in last })
            let row = try header.map { key -> String in
                guard let value = byKey[key] else { return "" }
                return csvField(try scalarString(value, key: key))
            }
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func scalarString(_ value: OrderedJSONValue, key: String) throws -> String {
        switch value {
        case .null:
            return ""
        case .bool(let bool):
            return bool ? "true" : "false"
        case .number(let raw):
            return raw
        case .string(let string):
            return string
        case .object, .array:
            throw CSVJSONConversionError.jsonNotFlatArrayOfObjects("key \"\(key)\" has a nested object/array value")
        }
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    /// Escapes a string as a JSON string literal (with surrounding quotes).
    /// Used instead of `JSONSerialization` for encoding so that CSV -> JSON
    /// output preserves the header's column order — `JSONSerialization`
    /// gives no ordering guarantee for `[String: Any]`. See
    /// `JSONTextEscaping` (OrderedJSONParser.swift) for the implementation,
    /// shared with `OrderedJSONValue.prettyPrinted`.
    private static func jsonStringLiteral(_ value: String) -> String {
        JSONTextEscaping.stringLiteral(value)
    }
}
