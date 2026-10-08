// Generated from a TL schema. Do not edit manually.

import Foundation

import EverTL

public struct FixtureBufferConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xb61af044 }
    public var payload: Foundation.Data
    public var revision: Swift.Int64

    public init(payload _tlArgument0: Foundation.Data, revision _tlArgument1: Swift.Int64) {
        self.payload = _tlArgument0
        self.revision = _tlArgument1
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Foundation.Data.self, boxed: false)
        let _tlField1 = try reader.read(Swift.Int64.self, boxed: false)
        return Self(payload: _tlField0, revision: _tlField1)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.payload, boxed: false)
        try writer.write(self.revision, boxed: false)
    }
}

public struct FixtureFlagsConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x89ad926c }
    public var mask: Swift.UInt32
    public var token: Swift.UInt32?
    public var urgent: Swift.Bool
    public var ready: Swift.Bool?

    public init(mask _tlArgument0: Swift.UInt32 = 0, token _tlArgument1: Swift.UInt32? = nil, urgent _tlArgument2: Swift.Bool = false, ready _tlArgument3: Swift.Bool? = nil) {
        self.mask = _tlArgument0
        self.token = _tlArgument1
        self.urgent = _tlArgument2
        self.ready = _tlArgument3
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField1: Swift.UInt32? = (_tlField0 & (Swift.UInt32(1) << 0)) != 0 ? try reader.read(Swift.UInt32.self, boxed: false) : nil
        let _tlField2 = (_tlField0 & (Swift.UInt32(1) << 1)) != 0
        let _tlField3: Swift.Bool? = (_tlField0 & (Swift.UInt32(1) << 31)) != 0 ? try reader.read(Swift.Bool.self, boxed: true) : nil
        return Self(mask: _tlField0, token: _tlField1, urgent: _tlField2, ready: _tlField3)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        var _tlMask0 = self.mask
        if self.token != nil { _tlMask0 |= (Swift.UInt32(1) << 0) } else { _tlMask0 &= ~(Swift.UInt32(1) << 0) }
        if self.urgent { _tlMask0 |= (Swift.UInt32(1) << 1) } else { _tlMask0 &= ~(Swift.UInt32(1) << 1) }
        if self.ready != nil { _tlMask0 |= (Swift.UInt32(1) << 31) } else { _tlMask0 &= ~(Swift.UInt32(1) << 31) }
        try writer.write(_tlMask0, boxed: false)
        if let _tlValue1 = self.token {
            try writer.write(_tlValue1, boxed: false)
        }
        if let _tlValue3 = self.ready {
            try writer.write(_tlValue3, boxed: true)
        }
    }
}

public struct FixtureGetRecordRequest: TLConstructor, TLFunction, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x9a422e13 }
    public typealias Reply = FixtureRecord
    public static var replyBoxed: Swift.Bool { true }

    public init() {
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        return Self()
    }

    public func writeBare(to writer: inout TLWriter) throws {
    }
}

public struct FixtureInvokeRequest<X: TLFunction>: TLConstructor, TLFunction, Sendable {
    public static var constructorID: Swift.UInt32 { 0x04d05bd8 }
    public typealias Reply = X.Reply
    public static var replyBoxed: Swift.Bool { X.replyBoxed }
    public var query: X

    public init(query _tlArgument0: X) {
        self.query = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(X.self, boxed: true)
        return Self(query: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.query, boxed: true)
    }
}

extension FixtureInvokeRequest: Equatable where X: Equatable {}

public struct FixtureKeywordsConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x086d0f11 }
    public var `self`: Swift.Int32
    public var `class`: Swift.Int32

    public init(`self` _tlArgument0: Swift.Int32, `class` _tlArgument1: Swift.Int32) {
        self.`self` = _tlArgument0
        self.`class` = _tlArgument1
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int32.self, boxed: false)
        let _tlField1 = try reader.read(Swift.Int32.self, boxed: false)
        return Self(self: _tlField0, class: _tlField1)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.`self`, boxed: false)
        try writer.write(self.`class`, boxed: false)
    }
}

public struct FixtureListRequest: TLConstructor, TLFunction, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x5271f753 }
    public typealias Reply = TLBoxedVector<FixtureRecord>
    public static var replyBoxed: Swift.Bool { false }
    public var marker: FixtureMarkerConstructor
    public var mode: Swift.UInt32
    public var count: Swift.UInt32
    public var descending: Swift.Bool
    public var include_hash: Swift.Bool

    public init(marker _tlArgument0: FixtureMarkerConstructor, mode _tlArgument1: Swift.UInt32 = 0, count _tlArgument2: Swift.UInt32, descending _tlArgument3: Swift.Bool = false, include_hash _tlArgument4: Swift.Bool = false) {
        self.marker = _tlArgument0
        self.mode = _tlArgument1
        self.count = _tlArgument2
        self.descending = _tlArgument3
        self.include_hash = _tlArgument4
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(FixtureMarkerConstructor.self, boxed: false)
        let _tlField1 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField2 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField3 = (_tlField1 & (Swift.UInt32(1) << 5)) != 0
        let _tlField4 = (_tlField1 & (Swift.UInt32(1) << 6)) != 0
        return Self(marker: _tlField0, mode: _tlField1, count: _tlField2, descending: _tlField3, include_hash: _tlField4)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        var _tlMask1 = self.mode
        if self.descending { _tlMask1 |= (Swift.UInt32(1) << 5) } else { _tlMask1 &= ~(Swift.UInt32(1) << 5) }
        if self.include_hash { _tlMask1 |= (Swift.UInt32(1) << 6) } else { _tlMask1 &= ~(Swift.UInt32(1) << 6) }
        try writer.write(self.marker, boxed: false)
        try writer.write(_tlMask1, boxed: false)
        try writer.write(self.count, boxed: false)
    }
}

public struct FixtureLookupRequest: TLConstructor, TLFunction, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x8cdf1b4f }
    public typealias Reply = FixtureMarker
    public static var replyBoxed: Swift.Bool { true }
    public var mode: Swift.UInt32
    public var marker: FixtureMarkerConstructor
    public var timestamp: Swift.Int64?

    public init(mode _tlArgument0: Swift.UInt32 = 0, marker _tlArgument1: FixtureMarkerConstructor, timestamp _tlArgument2: Swift.Int64? = nil) {
        self.mode = _tlArgument0
        self.marker = _tlArgument1
        self.timestamp = _tlArgument2
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField1 = try reader.read(FixtureMarkerConstructor.self, boxed: false)
        let _tlField2: Swift.Int64? = (_tlField0 & (Swift.UInt32(1) << 1)) != 0 ? try reader.read(Swift.Int64.self, boxed: false) : nil
        return Self(mode: _tlField0, marker: _tlField1, timestamp: _tlField2)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        var _tlMask0 = self.mode
        if self.timestamp != nil { _tlMask0 |= (Swift.UInt32(1) << 1) } else { _tlMask0 &= ~(Swift.UInt32(1) << 1) }
        try writer.write(_tlMask0, boxed: false)
        try writer.write(self.marker, boxed: false)
        if let _tlValue2 = self.timestamp {
            try writer.write(_tlValue2, boxed: false)
        }
    }
}

public struct FixtureMarkerConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x3a837661 }
    public var chain: Swift.Int32
    public var epoch: Swift.UInt64
    public var offset: Swift.UInt32
    public var digest: TLBytes256

    public init(chain _tlArgument0: Swift.Int32, epoch _tlArgument1: Swift.UInt64, offset _tlArgument2: Swift.UInt32, digest _tlArgument3: TLBytes256) {
        self.chain = _tlArgument0
        self.epoch = _tlArgument1
        self.offset = _tlArgument2
        self.digest = _tlArgument3
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int32.self, boxed: false)
        let _tlField1 = try reader.read(Swift.UInt64.self, boxed: false)
        let _tlField2 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField3 = try reader.read(TLBytes256.self, boxed: false)
        return Self(chain: _tlField0, epoch: _tlField1, offset: _tlField2, digest: _tlField3)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.chain, boxed: false)
        try writer.write(self.epoch, boxed: false)
        try writer.write(self.offset, boxed: false)
        try writer.write(self.digest, boxed: false)
    }
}

public struct FixtureNestedConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x1ed1cb0b }
    public var values: [TLBareVector<Swift.Int32>]

    public init(values _tlArgument0: [TLBareVector<Swift.Int32>]) {
        self.values = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.readVector(TLBareVector<Swift.Int32>.self, elementBoxed: false)
        return Self(values: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.writeVector(self.values, elementBoxed: false)
    }
}

public struct FixtureObjectConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xcfb7985d }
    public var value: TLObject

    public init(value _tlArgument0: TLObject) {
        self.value = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(TLObject.self, boxed: true)
        return Self(value: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.value, boxed: true)
    }
}

public struct FixturePingRequest: TLConstructor, TLFunction, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xb9bbf96e }
    public typealias Reply = FixturePong
    public static var replyBoxed: Swift.Bool { true }
    public var nonce: Swift.Int64

    public init(nonce _tlArgument0: Swift.Int64) {
        self.nonce = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int64.self, boxed: false)
        return Self(nonce: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.nonce, boxed: false)
    }
}

public struct FixturePongConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x28da29f7 }
    public var nonce: Swift.Int64

    public init(nonce _tlArgument0: Swift.Int64) {
        self.nonce = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int64.self, boxed: false)
        return Self(nonce: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.nonce, boxed: false)
    }
}

public struct FixturePrefixedConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x1e6c03ca }
    public var value: TLLengthPrefixed<TLObject>

    public init(value _tlArgument0: TLLengthPrefixed<TLObject>) {
        self.value = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(TLLengthPrefixed<TLObject>.self, boxed: false)
        return Self(value: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.value, boxed: false)
    }
}

public struct FixtureRecordConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x19ba8f02 }
    public var index: Swift.UInt32
    public var enabled: Swift.Bool
    public var checksum: Swift.UInt32

    public init(index _tlArgument0: Swift.UInt32, enabled _tlArgument1: Swift.Bool, checksum _tlArgument2: Swift.UInt32) {
        self.index = _tlArgument0
        self.enabled = _tlArgument1
        self.checksum = _tlArgument2
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField1 = try reader.read(Swift.Bool.self, boxed: true)
        let _tlField2 = try reader.read(Swift.UInt32.self, boxed: false)
        return Self(index: _tlField0, enabled: _tlField1, checksum: _tlField2)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.index, boxed: false)
        try writer.write(self.enabled, boxed: true)
        try writer.write(self.checksum, boxed: false)
    }
}

public struct FixtureSecretsConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xa5a099e3 }
    public var text: Foundation.Data
    public var bytes: Foundation.Data

    public init(text _tlArgument0: Foundation.Data, bytes _tlArgument1: Foundation.Data) {
        self.text = _tlArgument0
        self.bytes = _tlArgument1
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Foundation.Data.self, boxed: false)
        let _tlField1 = try reader.read(Foundation.Data.self, boxed: false)
        return Self(text: _tlField0, bytes: _tlField1)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.text, boxed: false)
        try writer.write(self.bytes, boxed: false)
    }
}

public struct FixtureSharedConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x7cdc0bb8 }
    public var mask: Swift.UInt32
    public var left: Swift.Int32?
    public var right: Swift.Int32?

    public init(mask _tlArgument0: Swift.UInt32 = 0, left _tlArgument1: Swift.Int32? = nil, right _tlArgument2: Swift.Int32? = nil) {
        self.mask = _tlArgument0
        self.left = _tlArgument1
        self.right = _tlArgument2
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt32.self, boxed: false)
        let _tlField1: Swift.Int32? = (_tlField0 & (Swift.UInt32(1) << 2)) != 0 ? try reader.read(Swift.Int32.self, boxed: false) : nil
        let _tlField2: Swift.Int32? = (_tlField0 & (Swift.UInt32(1) << 2)) != 0 ? try reader.read(Swift.Int32.self, boxed: false) : nil
        return Self(mask: _tlField0, left: _tlField1, right: _tlField2)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        var _tlMask0 = self.mask
        guard (self.left != nil) == (self.right != nil) else {
            throw TLCodecError.inconsistentFlags("fixture.shared: mask.2 requires left, right to be present together")
        }
        if self.left != nil { _tlMask0 |= (Swift.UInt32(1) << 2) } else { _tlMask0 &= ~(Swift.UInt32(1) << 2) }
        try writer.write(_tlMask0, boxed: false)
        if let _tlValue1 = self.left {
            try writer.write(_tlValue1, boxed: false)
        }
        if let _tlValue2 = self.right {
            try writer.write(_tlValue2, boxed: false)
        }
    }
}

public struct FixtureSmallMaskConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xe923d6bd }
    public var bits: Swift.UInt8
    public var marker: FixtureMarkerConstructor?

    public init(bits _tlArgument0: Swift.UInt8 = 0, marker _tlArgument1: FixtureMarkerConstructor? = nil) {
        self.bits = _tlArgument0
        self.marker = _tlArgument1
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt8.self, boxed: false)
        let _tlField1: FixtureMarkerConstructor? = (_tlField0 & (Swift.UInt8(1) << 7)) != 0 ? try reader.read(FixtureMarkerConstructor.self, boxed: false) : nil
        return Self(bits: _tlField0, marker: _tlField1)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        var _tlMask0 = self.bits
        if self.marker != nil { _tlMask0 |= (Swift.UInt8(1) << 7) } else { _tlMask0 &= ~(Swift.UInt8(1) << 7) }
        try writer.write(_tlMask0, boxed: false)
        if let _tlValue1 = self.marker {
            try writer.write(_tlValue1, boxed: false)
        }
    }
}

public struct FixtureVectorsConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xd380633f }
    public var bare: [FixtureRecordConstructor]
    public var boxed: [FixtureRecord]

    public init(bare _tlArgument0: [FixtureRecordConstructor], boxed _tlArgument1: [FixtureRecord]) {
        self.bare = _tlArgument0
        self.boxed = _tlArgument1
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.readVector(FixtureRecordConstructor.self, elementBoxed: false)
        let _tlField1 = try reader.readVector(FixtureRecord.self, elementBoxed: true)
        return Self(bare: _tlField0, boxed: _tlField1)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.writeVector(self.bare, elementBoxed: false)
        try writer.writeVector(self.boxed, elementBoxed: true)
    }
}

public struct FixtureWideConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0x28f20c54 }
    public var maximum: Swift.UInt64
    public var minimum: Swift.Int64
    public var extra: Swift.UInt64

    public init(maximum _tlArgument0: Swift.UInt64, minimum _tlArgument1: Swift.Int64, extra _tlArgument2: Swift.UInt64) {
        self.maximum = _tlArgument0
        self.minimum = _tlArgument1
        self.extra = _tlArgument2
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.UInt64.self, boxed: false)
        let _tlField1 = try reader.read(Swift.Int64.self, boxed: false)
        let _tlField2 = try reader.read(Swift.UInt64.self, boxed: false)
        return Self(maximum: _tlField0, minimum: _tlField1, extra: _tlField2)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.maximum, boxed: false)
        try writer.write(self.minimum, boxed: false)
        try writer.write(self.extra, boxed: false)
    }
}

public struct PayloadEntryAsModelEntryConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xac08bea0 }
    public var version: Swift.Int32

    public init(version _tlArgument0: Swift.Int32) {
        self.version = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int32.self, boxed: false)
        return Self(version: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.version, boxed: false)
    }
}

public struct PayloadEntryAsPayloadEntryConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xd756d480 }
    public var key: TLBytes256

    public init(key _tlArgument0: TLBytes256) {
        self.key = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(TLBytes256.self, boxed: false)
        return Self(key: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.key, boxed: false)
    }
}

public struct Project_TokenConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xd78bdfee }
    public var value: Swift.Int32

    public init(value _tlArgument0: Swift.Int32) {
        self.value = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Swift.Int32.self, boxed: false)
        return Self(value: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.value, boxed: false)
    }
}

public struct ProjectTokenConstructor: TLConstructor, Equatable, Sendable {
    public static var constructorID: Swift.UInt32 { 0xe3588da8 }
    public var value: Foundation.Data

    public init(value _tlArgument0: Foundation.Data) {
        self.value = _tlArgument0
    }

    public static func readBare(from reader: inout TLReader) throws -> Self {
        let _tlField0 = try reader.read(Foundation.Data.self, boxed: false)
        return Self(value: _tlField0)
    }

    public func writeBare(to writer: inout TLWriter) throws {
        try writer.write(self.value, boxed: false)
    }
}

public indirect enum FixtureBuffer: TLBoxedSerializable, Equatable, Sendable {
    case fixtureBuffer(FixtureBufferConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.buffer requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xb61af044: return .fixtureBuffer(try FixtureBufferConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.buffer requires a constructor identifier") }
        switch self {
        case .fixtureBuffer(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureFlags: TLBoxedSerializable, Equatable, Sendable {
    case fixtureFlags(FixtureFlagsConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.flags requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x89ad926c: return .fixtureFlags(try FixtureFlagsConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.flags requires a constructor identifier") }
        switch self {
        case .fixtureFlags(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureKeywords: TLBoxedSerializable, Equatable, Sendable {
    case fixtureKeywords(FixtureKeywordsConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.keywords requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x086d0f11: return .fixtureKeywords(try FixtureKeywordsConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.keywords requires a constructor identifier") }
        switch self {
        case .fixtureKeywords(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureMarker: TLBoxedSerializable, Equatable, Sendable {
    case fixtureMarker(FixtureMarkerConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.marker requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x3a837661: return .fixtureMarker(try FixtureMarkerConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.marker requires a constructor identifier") }
        switch self {
        case .fixtureMarker(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureNested: TLBoxedSerializable, Equatable, Sendable {
    case fixtureNested(FixtureNestedConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.nested requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x1ed1cb0b: return .fixtureNested(try FixtureNestedConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.nested requires a constructor identifier") }
        switch self {
        case .fixtureNested(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureObject: TLBoxedSerializable, Equatable, Sendable {
    case fixtureObject(FixtureObjectConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.object requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xcfb7985d: return .fixtureObject(try FixtureObjectConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.object requires a constructor identifier") }
        switch self {
        case .fixtureObject(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixturePong: TLBoxedSerializable, Equatable, Sendable {
    case fixturePong(FixturePongConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.pong requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x28da29f7: return .fixturePong(try FixturePongConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.pong requires a constructor identifier") }
        switch self {
        case .fixturePong(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixturePrefixed: TLBoxedSerializable, Equatable, Sendable {
    case fixturePrefixed(FixturePrefixedConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.prefixed requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x1e6c03ca: return .fixturePrefixed(try FixturePrefixedConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.prefixed requires a constructor identifier") }
        switch self {
        case .fixturePrefixed(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureRecord: TLBoxedSerializable, Equatable, Sendable {
    case fixtureRecord(FixtureRecordConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.record requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x19ba8f02: return .fixtureRecord(try FixtureRecordConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.record requires a constructor identifier") }
        switch self {
        case .fixtureRecord(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureSecrets: TLBoxedSerializable, Equatable, Sendable {
    case fixtureSecrets(FixtureSecretsConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.secrets requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xa5a099e3: return .fixtureSecrets(try FixtureSecretsConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.secrets requires a constructor identifier") }
        switch self {
        case .fixtureSecrets(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureShared: TLBoxedSerializable, Equatable, Sendable {
    case fixtureShared(FixtureSharedConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.shared requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x7cdc0bb8: return .fixtureShared(try FixtureSharedConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.shared requires a constructor identifier") }
        switch self {
        case .fixtureShared(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureSmallMask: TLBoxedSerializable, Equatable, Sendable {
    case fixtureSmallMask(FixtureSmallMaskConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.smallMask requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xe923d6bd: return .fixtureSmallMask(try FixtureSmallMaskConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.smallMask requires a constructor identifier") }
        switch self {
        case .fixtureSmallMask(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureVectors: TLBoxedSerializable, Equatable, Sendable {
    case fixtureVectors(FixtureVectorsConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.vectors requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xd380633f: return .fixtureVectors(try FixtureVectorsConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.vectors requires a constructor identifier") }
        switch self {
        case .fixtureVectors(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum FixtureWide: TLBoxedSerializable, Equatable, Sendable {
    case fixtureWide(FixtureWideConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("fixture.wide requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0x28f20c54: return .fixtureWide(try FixtureWideConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("fixture.wide requires a constructor identifier") }
        switch self {
        case .fixtureWide(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum ModelEntry: TLBoxedSerializable, Equatable, Sendable {
    case payloadEntry(PayloadEntryAsModelEntryConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("model.entry requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xac08bea0: return .payloadEntry(try PayloadEntryAsModelEntryConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("model.entry requires a constructor identifier") }
        switch self {
        case .payloadEntry(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum PayloadEntry: TLBoxedSerializable, Equatable, Sendable {
    case payloadEntry(PayloadEntryAsPayloadEntryConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("payload.entry requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xd756d480: return .payloadEntry(try PayloadEntryAsPayloadEntryConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("payload.entry requires a constructor identifier") }
        switch self {
        case .payloadEntry(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum Project_Token: TLBoxedSerializable, Equatable, Sendable {
    case projectToken(Project_TokenConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("project.token requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xd78bdfee: return .projectToken(try Project_TokenConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("project.token requires a constructor identifier") }
        switch self {
        case .projectToken(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public indirect enum ProjectToken: TLBoxedSerializable, Equatable, Sendable {
    case projectToken(ProjectTokenConstructor)

    public static func read(from reader: inout TLReader, boxed: Swift.Bool) throws -> Self {
        guard boxed else { throw TLCodecError.unsupported("projectToken requires a constructor identifier") }
        let _tlID = try reader.read(Swift.UInt32.self, boxed: false)
        switch _tlID {
        case 0xe3588da8: return .projectToken(try ProjectTokenConstructor.readBare(from: &reader))
        default: throw TLCodecError.unknownConstructor(_tlID)
        }
    }

    public func write(to writer: inout TLWriter, boxed: Swift.Bool) throws {
        guard boxed else { throw TLCodecError.unsupported("projectToken requires a constructor identifier") }
        switch self {
        case .projectToken(let _tlValue): try _tlValue.write(to: &writer, boxed: true)
        }
    }
}

public enum EverTLSchema {
    public static let layer: Swift.UInt32? = nil
    public static let constructorCount: Swift.Int = 23
    public static func makeRegistry() throws -> TLRegistry {
        var registry = TLRegistry()
        try registry.register(FixtureBufferConstructor.self, id: 0xb61af044, name: "fixture.buffer")
        try registry.register(FixtureFlagsConstructor.self, id: 0x89ad926c, name: "fixture.flags")
        try registry.register(FixtureGetRecordRequest.self, id: 0x9a422e13, name: "fixture.getRecord")
        try registry.register(FixtureInvokeRequest<TLObject>.self, id: 0x04d05bd8, name: "fixture.invoke")
        try registry.register(FixtureKeywordsConstructor.self, id: 0x086d0f11, name: "fixture.keywords")
        try registry.register(FixtureListRequest.self, id: 0x5271f753, name: "fixture.list")
        try registry.register(FixtureLookupRequest.self, id: 0x8cdf1b4f, name: "fixture.lookup")
        try registry.register(FixtureMarkerConstructor.self, id: 0x3a837661, name: "fixture.marker")
        try registry.register(FixtureNestedConstructor.self, id: 0x1ed1cb0b, name: "fixture.nested")
        try registry.register(FixtureObjectConstructor.self, id: 0xcfb7985d, name: "fixture.object")
        try registry.register(FixturePingRequest.self, id: 0xb9bbf96e, name: "fixture.ping")
        try registry.register(FixturePongConstructor.self, id: 0x28da29f7, name: "fixture.pong")
        try registry.register(FixturePrefixedConstructor.self, id: 0x1e6c03ca, name: "fixture.prefixed")
        try registry.register(FixtureRecordConstructor.self, id: 0x19ba8f02, name: "fixture.record")
        try registry.register(FixtureSecretsConstructor.self, id: 0xa5a099e3, name: "fixture.secrets")
        try registry.register(FixtureSharedConstructor.self, id: 0x7cdc0bb8, name: "fixture.shared")
        try registry.register(FixtureSmallMaskConstructor.self, id: 0xe923d6bd, name: "fixture.smallMask")
        try registry.register(FixtureVectorsConstructor.self, id: 0xd380633f, name: "fixture.vectors")
        try registry.register(FixtureWideConstructor.self, id: 0x28f20c54, name: "fixture.wide")
        try registry.register(PayloadEntryAsModelEntryConstructor.self, id: 0xac08bea0, name: "payload.entry as model.Entry")
        try registry.register(PayloadEntryAsPayloadEntryConstructor.self, id: 0xd756d480, name: "payload.entry as payload.Entry")
        try registry.register(Project_TokenConstructor.self, id: 0xd78bdfee, name: "project.token")
        try registry.register(ProjectTokenConstructor.self, id: 0xe3588da8, name: "projectToken")
        return registry
    }
}
