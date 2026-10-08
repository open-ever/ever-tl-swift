public struct TLParseError: Error, Equatable, Sendable, CustomStringConvertible {
    public let message: String
    public let line: Int
    public let column: Int

    public init(message: String, line: Int, column: Int) {
        self.message = message
        self.line = line
        self.column = column
    }

    public var description: String {
        "\(line):\(column): \(message)"
    }
}

public enum TLParser {
    public static func parse(_ source: String) throws -> TLSchema {
        var parser = try SchemaParser(source: source)
        return try parser.parse()
    }
}

private enum TokenKind: Equatable {
    case identifier(String)
    case symbol(UInt8)
    case types
    case functions
    case layer(UInt32)
}

private struct Token {
    let kind: TokenKind
    let start: Int
    let end: Int
}

private struct SchemaParser {
    private let bytes: [UInt8]
    private let tokens: [Token]
    private var position = 0
    private var typeDepth = 0

    init(source: String) throws {
        bytes = Array(source.utf8)
        tokens = try Self.tokenize(bytes)
    }

    mutating func parse() throws -> TLSchema {
        var constructors: [TLConstructor] = []
        var layer: UInt32?
        var isFunction = false
        while let token = current {
            switch token.kind {
            case .types:
                isFunction = false
                position += 1
            case .functions:
                isFunction = true
                position += 1
            case .layer(let value):
                layer = value
                position += 1
            default:
                constructors.append(try parseConstructor(isFunction: isFunction))
            }
        }
        return TLSchema(constructors: constructors, layer: layer)
    }

    private var current: Token? {
        position < tokens.count ? tokens[position] : nil
    }

    private func isSymbol(_ symbol: UInt8, at offset: Int = 0) -> Bool {
        let index = position + offset
        return index < tokens.count && tokens[index].kind == .symbol(symbol)
    }

    @discardableResult
    private mutating func consume(_ symbol: UInt8) -> Bool {
        guard isSymbol(symbol) else { return false }
        position += 1
        return true
    }

    private mutating func expect(_ symbol: UInt8) throws {
        guard consume(symbol) else {
            throw error("Expected '\(Character(UnicodeScalar(symbol)))'")
        }
    }

    private mutating func identifier() throws -> String {
        guard let token = current, case .identifier(let name) = token.kind else {
            throw error("Expected an identifier")
        }
        position += 1
        return name
    }

    private mutating func dottedIdentifier() throws -> String {
        var name = try identifier()
        while consume(46) {
            name += "." + (try identifier())
        }
        return name
    }

    private mutating func parseConstructor(isFunction: Bool) throws -> TLConstructor {
        let start = current!.start
        let name = try dottedIdentifier()
        var explicitID: UInt32?
        if isSymbol(35), current!.start == tokens[position - 1].end {
            let idStart = current!.end
            position += 1
            let idPosition = current?.start ?? bytes.count
            guard current?.start == idStart else {
                throw error("Expected hexadecimal digits immediately after '#'", at: idStart)
            }
            let value = try identifier()
            guard value.utf8.count <= 8, value.utf8.allSatisfy(Self.isHexDigit),
                  let id = UInt32(value, radix: 16) else {
                throw error("Constructor ID must contain 1 to 8 hexadecimal digits", at: idPosition)
            }
            explicitID = id
        }

        var typeParameters: [TLField] = []
        var fields: [TLField] = []
        if !consume(63) {
            while consume(123) {
                let parameterName = try identifier()
                try expect(58)
                let type = try parseType()
                try expect(125)
                typeParameters.append(TLField(name: parameterName, type: type))
            }
            while !isSymbol(61) {
                guard current != nil else { throw error("Expected '='") }
                fields.append(try parseField())
            }
        }
        try expect(61)
        let resultStart = current?.start ?? bytes.count
        var result = try parseType()
        if let token = current, Self.canStartType(token.kind), case .named(let name) = result {
            result = .generic(name, try parseType())
        }
        let resultEnd = tokens[position - 1].end
        try expect(59)
        let end = tokens[position - 1].end

        // ever-tl normalizes input fields but hashes the original output spelling.
        var signature = name
        for parameter in typeParameters {
            signature += " {\(parameter.schemaText)}"
        }
        for field in fields {
            signature += " " + field.schemaText
        }
        signature += " = " + string(from: resultStart, to: resultEnd)

        return TLConstructor(
            name: name,
            id: explicitID ?? Self.crc32(signature.utf8),
            typeParameters: typeParameters,
            fields: fields,
            result: result,
            isFunction: isFunction,
            source: string(from: start, to: end)
        )
    }

    private mutating func parseField() throws -> TLField {
        if let token = current, case .identifier(let name) = token.kind,
           isSymbol(58, at: 1) {
            position += 2
            return TLField(name: name, type: try parseType())
        }
        return TLField(name: nil, type: try parseType())
    }

    private mutating func parseType() throws -> TLType {
        guard typeDepth < 256 else {
            throw error("Type nesting exceeds the maximum depth of 256")
        }
        typeDepth += 1
        defer { typeDepth -= 1 }

        if consume(35) { return .number }
        if consume(33) { return .typeParameter(try identifier()) }
        if consume(40) {
            let name = try dottedIdentifier()
            let argument = try parseType()
            try expect(41)
            return .generic(name, argument)
        }
        var repeatCount: UInt32?
        if let token = current, case .identifier(let value) = token.kind,
           isSymbol(42, at: 1) {
            guard value.utf8.allSatisfy(Self.isDigit), let count = UInt32(value) else {
                throw error("Repeat count must be an unsigned 32-bit decimal integer")
            }
            repeatCount = count
            position += 2
            guard isSymbol(91) else { throw error("Expected '[' after repeat count") }
        }
        if consume(91) {
            var fields: [TLField] = []
            while !isSymbol(93) {
                guard current != nil else { throw error("Expected ']'") }
                fields.append(try parseField())
            }
            try expect(93)
            return .repeated(repeatCount, fields)
        }

        let namePosition = current?.start ?? bytes.count
        let name = try dottedIdentifier()
        if consume(63) {
            let components = name.split(separator: ".")
            guard components.count == 2, components[1].utf8.allSatisfy(Self.isDigit),
                  let bit = UInt32(components[1]) else {
                throw error("Expected a flag reference of the form flags.0?Type", at: namePosition)
            }
            return .flagged(String(components[0]), bit, try parseType())
        }
        if consume(60) {
            let argument = try parseType()
            try expect(62)
            return .generic(name, argument)
        }
        return .named(name)
    }

    private func string(from start: Int, to end: Int) -> String {
        String(decoding: bytes[start..<end], as: UTF8.self)
    }

    private func error(_ message: String, at offset: Int? = nil) -> TLParseError {
        Self.error(message, at: offset ?? current?.start ?? bytes.count, in: bytes)
    }

    private static func error(_ message: String, at offset: Int, in bytes: [UInt8]) -> TLParseError {
        var line = 1
        var column = 1
        var previousWasCR = false
        for scalar in String(decoding: bytes[..<offset], as: UTF8.self).unicodeScalars {
            if scalar == "\r" {
                line += 1
                column = 1
            } else if scalar == "\n" {
                if !previousWasCR { line += 1 }
                column = 1
            } else {
                column += 1
            }
            previousWasCR = scalar == "\r"
        }
        return TLParseError(message: message, line: line, column: column)
    }

    private static func tokenize(_ bytes: [UInt8]) throws -> [Token] {
        var result: [Token] = []
        var offset = 0
        func matches(_ text: String, at offset: Int) -> Bool {
            let expected = Array(text.utf8)
            return offset + expected.count <= bytes.count
                && bytes[offset..<(offset + expected.count)].elementsEqual(expected)
        }
        while offset < bytes.count {
            let start = offset
            let byte = bytes[offset]
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 {
                offset += 1
            } else if matches("//", at: offset) {
                while offset < bytes.count && bytes[offset] != 10 && bytes[offset] != 13 {
                    offset += 1
                }
                if matches("// LAYER ", at: start) {
                    let valueStart = start + 9
                    var valueEnd = valueStart
                    while valueEnd < offset && isDigit(bytes[valueEnd]) { valueEnd += 1 }
                    let value = String(decoding: bytes[valueStart..<valueEnd], as: UTF8.self)
                    guard let layer = UInt32(value),
                          bytes[valueEnd..<offset].allSatisfy({ $0 == 32 || $0 == 9 }) else {
                        throw error("LAYER must be an unsigned 32-bit decimal integer", at: valueStart, in: bytes)
                    }
                    result.append(Token(kind: .layer(layer), start: start, end: offset))
                }
            } else if matches("/*", at: offset) {
                offset += 2
                while offset < bytes.count && !matches("*/", at: offset) { offset += 1 }
                guard offset < bytes.count else {
                    throw error("Unterminated block comment", at: start, in: bytes)
                }
                offset += 2
            } else if matches("---types---", at: offset) {
                offset += 11
                result.append(Token(kind: .types, start: start, end: offset))
            } else if matches("---functions---", at: offset) {
                offset += 15
                result.append(Token(kind: .functions, start: start, end: offset))
            } else if isIdentifierByte(byte) {
                while offset < bytes.count && isIdentifierByte(bytes[offset]) { offset += 1 }
                let value = String(decoding: bytes[start..<offset], as: UTF8.self)
                result.append(Token(kind: .identifier(value), start: start, end: offset))
            } else if Array("#.:=;!?{}[]()<>*".utf8).contains(byte) {
                offset += 1
                result.append(Token(kind: .symbol(byte), start: start, end: offset))
            } else {
                throw error("Unexpected character in TL schema", at: offset, in: bytes)
            }
        }
        return result
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 48 && byte <= 57
    }

    private static func canStartType(_ kind: TokenKind) -> Bool {
        switch kind {
        case .identifier:
            return true
        case .symbol(let byte):
            return byte == 35 || byte == 33 || byte == 40 || byte == 91
        default:
            return false
        }
    }

    private static func isIdentifierByte(_ byte: UInt8) -> Bool {
        isDigit(byte) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 95
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        isDigit(byte) || (byte >= 65 && byte <= 70) || (byte >= 97 && byte <= 102)
    }

    private static func crc32(_ bytes: String.UTF8View) -> UInt32 {
        var result = UInt32.max
        for byte in bytes {
            result ^= UInt32(byte)
            for _ in 0..<8 {
                result = (result >> 1) ^ (result & 1 == 0 ? 0 : 0xedb8_8320)
            }
        }
        return ~result
    }
}
