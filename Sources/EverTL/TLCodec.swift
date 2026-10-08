import Foundation

public enum TLCodecError: Error, Equatable, Sendable, CustomStringConvertible {
    case unexpectedEnd(offset: Int, requested: Int, remaining: Int)
    case invalidConstructor(expected: UInt32, actual: UInt32)
    case unknownConstructor(UInt32)
    case duplicateConstructor(UInt32)
    case duplicateName(String)
    case invalidLength(Int)
    case limitExceeded(String)
    case invalidUTF8
    case trailingBytes(Int)
    case inconsistentFlags(String)
    case unsupported(String)

    public var description: String {
        switch self {
        case let .unexpectedEnd(offset, requested, remaining):
            return "Unexpected end at offset \(offset): requested \(requested) bytes, \(remaining) remain"
        case let .invalidConstructor(expected, actual):
            return String(format: "Expected constructor #%08x, received #%08x", expected, actual)
        case let .unknownConstructor(id):
            return String(format: "Unknown constructor #%08x", id)
        case let .duplicateConstructor(id):
            return String(format: "Constructor #%08x is already registered", id)
        case let .duplicateName(name):
            return "Constructor name '\(name)' is already registered"
        case let .invalidLength(length):
            return "Invalid length \(length)"
        case let .limitExceeded(limit):
            return "Decoding limit exceeded: \(limit)"
        case .invalidUTF8:
            return "Invalid UTF-8 string"
        case let .trailingBytes(count):
            return "\(count) trailing bytes remain"
        case let .inconsistentFlags(field):
            return "Inconsistent flag fields: \(field)"
        case let .unsupported(feature):
            return "Unsupported TL representation: \(feature)"
        }
    }
}

public struct TLDecodingLimits: Equatable, Sendable {
    public var maxBytesLength: Int
    public var maxVectorCount: Int
    public var maxDepth: Int

    public init(
        maxBytesLength: Int = 0x00ff_ffff,
        maxVectorCount: Int = 1_000_000,
        maxDepth: Int = 128
    ) {
        self.maxBytesLength = maxBytesLength
        self.maxVectorCount = maxVectorCount
        self.maxDepth = maxDepth
    }
}

public protocol TLSerializable: Sendable {
    static func read(from reader: inout TLReader, boxed: Bool) throws -> Self
    func write(to writer: inout TLWriter, boxed: Bool) throws
}

public protocol TLBoxedSerializable: TLSerializable {}

public protocol TLConstructor: TLBoxedSerializable {
    static var constructorID: UInt32 { get }
    static func readBare(from reader: inout TLReader) throws -> Self
    func writeBare(to writer: inout TLWriter) throws
}

extension TLConstructor {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        if boxed {
            let actual = try reader.read(UInt32.self, boxed: false)
            guard actual == constructorID else {
                throw TLCodecError.invalidConstructor(expected: constructorID, actual: actual)
            }
        }
        return try readBare(from: &reader)
    }

    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        if boxed {
            try writer.write(Self.constructorID, boxed: false)
        }
        try writeBare(to: &writer)
    }
}

public protocol TLFunction: TLBoxedSerializable {
    associatedtype Reply: TLSerializable
    static var replyBoxed: Bool { get }
}

extension TLFunction {
    public static var replyBoxed: Bool { true }
}

public struct TLReader: Sendable {
    private let data: Data
    public private(set) var position: Int = 0
    public let registry: TLRegistry
    public let limits: TLDecodingLimits
    var depth: Int = 0

    public init(
        data: Data,
        registry: TLRegistry = .init(),
        limits: TLDecodingLimits = .init()
    ) {
        self.data = data
        self.registry = registry
        self.limits = limits
    }

    public var remainingCount: Int { data.count - position }
    public var isAtEnd: Bool { remainingCount == 0 }
    public var remainingData: Data { Data(data.dropFirst(position)) }

    public mutating func read<T: TLSerializable>(_ type: T.Type, boxed: Bool = true) throws -> T {
        try withDepth { reader in
            try type.read(from: &reader, boxed: boxed)
        }
    }

    public mutating func withDepth<T>(_ body: (inout TLReader) throws -> T) throws -> T {
        try enterContainer()
        defer { depth -= 1 }
        return try body(&self)
    }

    public mutating func readRaw(count: Int) throws -> Data {
        guard count >= 0 else { throw TLCodecError.invalidLength(count) }
        guard count <= remainingCount else {
            throw TLCodecError.unexpectedEnd(offset: position, requested: count, remaining: remainingCount)
        }
        let start = data.index(data.startIndex, offsetBy: position)
        let end = data.index(start, offsetBy: count)
        position += count
        return Data(data[start..<end])
    }

    public mutating func readVector<T: TLSerializable>(
        _ type: T.Type,
        elementBoxed: Bool
    ) throws -> [T] {
        try enterContainer()
        defer { depth -= 1 }
        let count = Int(try read(Int32.self, boxed: false))
        guard count >= 0 else { throw TLCodecError.invalidLength(count) }
        guard count <= limits.maxVectorCount else {
            throw TLCodecError.limitExceeded("vector count \(count) > \(limits.maxVectorCount)")
        }
        var values: [T] = []
        for _ in 0..<count {
            values.append(try read(type, boxed: elementBoxed))
        }
        return values
    }

    mutating func enterContainer() throws {
        guard depth < limits.maxDepth else {
            throw TLCodecError.limitExceeded("nesting depth > \(limits.maxDepth)")
        }
        depth += 1
    }

    func validateBytesLength(_ count: Int) throws {
        guard count >= 0 else { throw TLCodecError.invalidLength(count) }
        guard count <= limits.maxBytesLength else {
            throw TLCodecError.limitExceeded("byte length \(count) > \(limits.maxBytesLength)")
        }
    }

    mutating func readInteger<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let bytes = try readRaw(count: MemoryLayout<T>.size)
        var result: T = 0
        for (offset, byte) in bytes.enumerated() {
            result |= T(truncatingIfNeeded: byte) << (offset * 8)
        }
        return result
    }

    mutating func readBytes() throws -> Data {
        let first = try readInteger(UInt8.self)
        let prefixLength: Int
        let count: Int
        if first == 254 {
            let lengthBytes = try readRaw(count: 3)
            count = lengthBytes.enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }
            prefixLength = 4
        } else {
            count = Int(first)
            prefixLength = 1
        }
        try validateBytesLength(count)
        let payload = try readRaw(count: count)
        let padding = (4 - (prefixLength + count) % 4) % 4
        _ = try readRaw(count: padding)
        return payload
    }
}

public struct TLWriter: Sendable {
    public private(set) var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public mutating func write<T: TLSerializable>(_ value: T, boxed: Bool = true) throws {
        try value.write(to: &self, boxed: boxed)
    }

    public mutating func writeRaw(_ bytes: Data) {
        data.append(bytes)
    }

    public mutating func writeVector<T: TLSerializable>(_ values: [T], elementBoxed: Bool) throws {
        guard let count = Int32(exactly: values.count) else {
            throw TLCodecError.invalidLength(values.count)
        }
        try write(count, boxed: false)
        for value in values {
            try write(value, boxed: elementBoxed)
        }
    }

    mutating func writeInteger<T: FixedWidthInteger>(_ value: T) {
        for offset in 0..<MemoryLayout<T>.size {
            data.append(UInt8(truncatingIfNeeded: value >> (offset * 8)))
        }
    }

    mutating func writeBytes(_ bytes: Data) throws {
        let count = bytes.count
        guard count <= 0x00ff_ffff else { throw TLCodecError.invalidLength(count) }
        let prefixLength: Int
        if count < 254 {
            writeInteger(UInt8(count))
            prefixLength = 1
        } else {
            writeInteger(UInt8(254))
            for offset in 0..<3 {
                writeInteger(UInt8(truncatingIfNeeded: count >> (offset * 8)))
            }
            prefixLength = 4
        }
        writeRaw(bytes)
        let padding = (4 - (prefixLength + count) % 4) % 4
        writeRaw(Data(repeating: 0, count: padding))
    }
}

public enum TLCodec {
    public static func encode<T: TLSerializable>(_ value: T, boxed: Bool = true) throws -> Data {
        var writer = TLWriter()
        try writer.write(value, boxed: boxed)
        return writer.data
    }

    public static func decode<T: TLSerializable>(
        _ type: T.Type,
        from data: Data,
        boxed: Bool = true,
        registry: TLRegistry = .init(),
        limits: TLDecodingLimits = .init(),
        requireExhaustion: Bool = true
    ) throws -> T {
        var reader = TLReader(data: data, registry: registry, limits: limits)
        let value = try reader.read(type, boxed: boxed)
        if requireExhaustion, !reader.isAtEnd {
            throw TLCodecError.trailingBytes(reader.remainingCount)
        }
        return value
    }

    public static func decodePrefix<T: TLSerializable>(
        _ type: T.Type,
        from data: Data,
        boxed: Bool = true,
        registry: TLRegistry = .init(),
        limits: TLDecodingLimits = .init()
    ) throws -> (value: T, consumed: Int) {
        var reader = TLReader(data: data, registry: registry, limits: limits)
        let value = try reader.read(type, boxed: boxed)
        return (value, reader.position)
    }

    public static func decodeBundle(
        from data: Data,
        registry: TLRegistry,
        limits: TLDecodingLimits = .init()
    ) throws -> [TLObject] {
        var reader = TLReader(data: data, registry: registry, limits: limits)
        var objects: [TLObject] = []
        while !reader.isAtEnd {
            objects.append(try reader.read(TLObject.self))
        }
        return objects
    }

    public static func decodeBundlePrefix(
        from data: Data,
        registry: TLRegistry,
        limits: TLDecodingLimits = .init()
    ) throws -> (values: [TLObject], consumed: Int) {
        var reader = TLReader(data: data, registry: registry, limits: limits)
        var objects: [TLObject] = []
        while !reader.isAtEnd {
            var candidate = reader
            do {
                let object = try candidate.read(TLObject.self)
                objects.append(object)
                reader = candidate
            } catch {
                if objects.isEmpty { throw error }
                break
            }
        }
        return (objects, reader.position)
    }
}
