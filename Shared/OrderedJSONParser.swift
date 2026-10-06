import Foundation

/// A parsed JSON value that preserves object key order. `JSONSerialization`
/// deserializes objects into `[String: Any]`, which has no ordering
/// guarantee — unsuitable for JSON → CSV, where column order needs to match
/// the source JSON's key order for the output to look sane and deterministic
/// rather than shuffled differently on every conversion.
indirect enum OrderedJSONValue: Equatable {
    case string(String)
    case number(String) // Kept as the original raw text — avoids any Double round-tripping precision loss.
    case bool(Bool)
    case null
    case object([(String, OrderedJSONValue)])
    case array([OrderedJSONValue])

    static func == (lhs: OrderedJSONValue, rhs: OrderedJSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.null, .null): return true
        case (.object(let a), .object(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.array(let a), .array(let b)): return a == b
        default: return false
        }
    }

    /// Two-space-indented pretty-printed JSON text, preserving the original
    /// key order — unlike `JSONSerialization`'s pretty-printing, which gives
    /// no ordering guarantee for object keys.
    func prettyPrinted(indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        let childPad = String(repeating: "  ", count: indent + 1)
        switch self {
        case .string(let value):
            return JSONTextEscaping.stringLiteral(value)
        case .number(let raw):
            return raw
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .object(let pairs):
            guard !pairs.isEmpty else { return "{}" }
            let lines = pairs.map { key, value in
                "\(childPad)\(JSONTextEscaping.stringLiteral(key)): \(value.prettyPrinted(indent: indent + 1))"
            }
            return "{\n" + lines.joined(separator: ",\n") + "\n\(pad)}"
        case .array(let elements):
            guard !elements.isEmpty else { return "[]" }
            let lines = elements.map { "\(childPad)\($0.prettyPrinted(indent: indent + 1))" }
            return "[\n" + lines.joined(separator: ",\n") + "\n\(pad)]"
        }
    }
}

/// Shared by `OrderedJSONValue.prettyPrinted` and `CSVJSONConversion` so
/// there's exactly one place that knows how to escape a JSON string literal.
enum JSONTextEscaping {
    static func stringLiteral(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    result += String(format: "\\u%04x", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        result += "\""
        return result
    }
}

struct OrderedJSONParseError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A small hand-rolled recursive-descent JSON parser — only exists because
/// `JSONSerialization` can't preserve key order (see `OrderedJSONValue`).
/// Supports the full JSON grammar (not just flat objects) so it can give a
/// precise error when something unexpectedly nested shows up.
enum OrderedJSONParser {

    static func parse(_ text: String) throws -> OrderedJSONValue {
        var chars = Substring(text)
        skipWhitespace(&chars)
        let value = try parseValue(&chars)
        skipWhitespace(&chars)
        guard chars.isEmpty else {
            throw OrderedJSONParseError(message: "unexpected trailing content")
        }
        return value
    }

    private static func parseValue(_ chars: inout Substring) throws -> OrderedJSONValue {
        skipWhitespace(&chars)
        guard let first = chars.first else {
            throw OrderedJSONParseError(message: "unexpected end of input")
        }

        switch first {
        case "{": return try parseObject(&chars)
        case "[": return try parseArray(&chars)
        case "\"": return .string(try parseString(&chars))
        case "t": try expect("true", &chars); return .bool(true)
        case "f": try expect("false", &chars); return .bool(false)
        case "n": try expect("null", &chars); return .null
        default: return .number(try parseNumber(&chars))
        }
    }

    private static func parseObject(_ chars: inout Substring) throws -> OrderedJSONValue {
        chars.removeFirst() // "{"
        var pairs: [(String, OrderedJSONValue)] = []
        skipWhitespace(&chars)
        if chars.first == "}" {
            chars.removeFirst()
            return .object(pairs)
        }
        while true {
            skipWhitespace(&chars)
            guard chars.first == "\"" else {
                throw OrderedJSONParseError(message: "expected a string key")
            }
            let key = try parseString(&chars)
            skipWhitespace(&chars)
            guard chars.first == ":" else {
                throw OrderedJSONParseError(message: "expected ':' after object key")
            }
            chars.removeFirst()
            let value = try parseValue(&chars)
            pairs.append((key, value))
            skipWhitespace(&chars)
            guard let next = chars.first else {
                throw OrderedJSONParseError(message: "unterminated object")
            }
            if next == "," {
                chars.removeFirst()
                continue
            } else if next == "}" {
                chars.removeFirst()
                break
            } else {
                throw OrderedJSONParseError(message: "expected ',' or '}' in object")
            }
        }
        return .object(pairs)
    }

    private static func parseArray(_ chars: inout Substring) throws -> OrderedJSONValue {
        chars.removeFirst() // "["
        var elements: [OrderedJSONValue] = []
        skipWhitespace(&chars)
        if chars.first == "]" {
            chars.removeFirst()
            return .array(elements)
        }
        while true {
            let value = try parseValue(&chars)
            elements.append(value)
            skipWhitespace(&chars)
            guard let next = chars.first else {
                throw OrderedJSONParseError(message: "unterminated array")
            }
            if next == "," {
                chars.removeFirst()
                continue
            } else if next == "]" {
                chars.removeFirst()
                break
            } else {
                throw OrderedJSONParseError(message: "expected ',' or ']' in array")
            }
        }
        return .array(elements)
    }

    private static func parseString(_ chars: inout Substring) throws -> String {
        chars.removeFirst() // opening quote
        var result = ""
        while let char = chars.first {
            chars.removeFirst()
            if char == "\"" {
                return result
            }
            if char == "\\" {
                guard let escaped = chars.first else {
                    throw OrderedJSONParseError(message: "unterminated escape sequence")
                }
                chars.removeFirst()
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u":
                    guard chars.count >= 4 else {
                        throw OrderedJSONParseError(message: "invalid unicode escape")
                    }
                    let hex = chars.prefix(4)
                    chars.removeFirst(4)
                    guard let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) else {
                        throw OrderedJSONParseError(message: "invalid unicode escape")
                    }
                    result.unicodeScalars.append(scalar)
                default:
                    throw OrderedJSONParseError(message: "invalid escape sequence \\\(escaped)")
                }
            } else {
                result.append(char)
            }
        }
        throw OrderedJSONParseError(message: "unterminated string")
    }

    private static func parseNumber(_ chars: inout Substring) throws -> String {
        var text = ""
        let allowed = Set("0123456789+-.eE")
        while let char = chars.first, allowed.contains(char) {
            text.append(char)
            chars.removeFirst()
        }
        guard !text.isEmpty, Double(text) != nil else {
            throw OrderedJSONParseError(message: "invalid number literal near \"\(text)\"")
        }
        return text
    }

    private static func expect(_ literal: String, _ chars: inout Substring) throws {
        guard chars.hasPrefix(literal) else {
            throw OrderedJSONParseError(message: "expected \"\(literal)\"")
        }
        chars.removeFirst(literal.count)
    }

    private static func skipWhitespace(_ chars: inout Substring) {
        while let char = chars.first, char == " " || char == "\t" || char == "\n" || char == "\r" {
            chars.removeFirst()
        }
    }
}
