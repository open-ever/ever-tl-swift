import Foundation

extension UInt8: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension Int8: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension Int32: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension UInt32: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension Int64: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension UInt64: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readInteger(Self.self)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(self)
    }
}

extension Double: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        Self(bitPattern: try reader.readInteger(UInt64.self))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        writer.writeInteger(bitPattern)
    }
}

extension Data: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readBytes()
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        try writer.writeBytes(self)
    }
}

extension String: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        guard let value = String(data: try reader.readBytes(), encoding: .utf8) else {
            throw TLCodecError.invalidUTF8
        }
        return value
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        try writer.writeBytes(Data(utf8))
    }
}

extension Bool: TLBoxedSerializable {
    public static let trueConstructorID: UInt32 = 0x9972_75b5
    public static let falseConstructorID: UInt32 = 0xbc79_9737

    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("bare Bool") }
        let id = try reader.read(UInt32.self, boxed: false)
        switch id {
        case trueConstructorID: return true
        case falseConstructorID: return false
        default: throw TLCodecError.unknownConstructor(id)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("bare Bool") }
        try writer.write(self ? Self.trueConstructorID : Self.falseConstructorID, boxed: false)
    }
}

public struct TLTrue: TLConstructor, Equatable, Hashable, Sendable {
    public static let constructorID: UInt32 = 0x3fed_d339
    public init() {}
    public static func readBare(from reader: inout TLReader) throws -> Self { .init() }
    public func writeBare(to writer: inout TLWriter) throws {}
}

public struct TLBytes128: TLSerializable, Equatable, Hashable, Sendable {
    public let data: Data

    public init() { data = Data(repeating: 0, count: 16) }
    public init(_ data: Data) throws {
        guard data.count == 16 else { throw TLCodecError.invalidLength(data.count) }
        self.data = data
    }
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try Self(reader.readRaw(count: 16))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws { writer.writeRaw(data) }
}

public struct TLBytes256: TLSerializable, Equatable, Hashable, Sendable {
    public let data: Data

    public init() { data = Data(repeating: 0, count: 32) }
    public init(_ data: Data) throws {
        guard data.count == 32 else { throw TLCodecError.invalidLength(data.count) }
        self.data = data
    }
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try Self(reader.readRaw(count: 32))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws { writer.writeRaw(data) }
}

public struct TLBytes512: TLSerializable, Equatable, Hashable, Sendable {
    public let data: Data

    public init() { data = Data(repeating: 0, count: 64) }
    public init(_ data: Data) throws {
        guard data.count == 64 else { throw TLCodecError.invalidLength(data.count) }
        self.data = data
    }
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try Self(reader.readRaw(count: 64))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws { writer.writeRaw(data) }
}

extension Array: TLSerializable where Element: TLSerializable {
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        try reader.readVector(Element.self, elementBoxed: true)
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        try writer.writeVector(self, elementBoxed: true)
    }
}

public struct TLBareVector<Element: TLSerializable>: TLSerializable, Sendable {
    public var values: [Element]
    public init(_ values: [Element] = []) { self.values = values }
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        Self(try reader.readVector(Element.self, elementBoxed: false))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        try writer.writeVector(values, elementBoxed: false)
    }
}

extension TLBareVector: Equatable where Element: Equatable {}
extension TLBareVector: Hashable where Element: Hashable {}

public struct TLBoxedVector<Element: TLSerializable>: TLSerializable, Sendable {
    public var values: [Element]
    public init(_ values: [Element] = []) { self.values = values }
    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        Self(try reader.readVector(Element.self, elementBoxed: true))
    }
    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        try writer.writeVector(values, elementBoxed: true)
    }
}

extension TLBoxedVector: Equatable where Element: Equatable {}
extension TLBoxedVector: Hashable where Element: Hashable {}

public struct TLLengthPrefixed<Value: TLSerializable>: TLSerializable, Sendable {
    public var value: Value

    public init(_ value: Value) { self.value = value }

    public static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        let count = Int(try reader.read(Int32.self, boxed: false))
        try reader.validateBytesLength(count)
        let payload = try reader.readRaw(count: count)
        var inner = TLReader(data: payload, registry: reader.registry, limits: reader.limits)
        inner.depth = reader.depth
        let value = try inner.read(Value.self, boxed: true)
        guard inner.isAtEnd else { throw TLCodecError.trailingBytes(inner.remainingCount) }
        return Self(value)
    }

    public func write(to writer: inout TLWriter, boxed: Bool) throws {
        let payload = try TLCodec.encode(value, boxed: true)
        guard let count = Int32(exactly: payload.count) else {
            throw TLCodecError.invalidLength(payload.count)
        }
        try writer.write(count, boxed: false)
        writer.writeRaw(payload)
    }
}

extension TLLengthPrefixed: Equatable where Value: Equatable {}
extension TLLengthPrefixed: Hashable where Value: Hashable {}
