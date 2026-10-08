import Foundation
import XCTest
@testable import EverTL

final class TLRuntimeTests: XCTestCase {
    func testBroxusBoxedPrimitiveFixture() throws {
        let value = PrimitiveFixture(item: 0xad, what: true, another: 123)
        let fixture = hex("ffffffffad000000b57572997b000000")
        XCTAssertEqual(try TLCodec.encode(value), fixture)
        XCTAssertEqual(try TLCodec.decode(PrimitiveFixture.self, from: fixture), value)
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), Data(fixture.dropFirst(4)))
        XCTAssertEqual(try TLCodec.decode(PrimitiveFixture.self, from: Data(fixture.dropFirst(4)), boxed: false), value)
    }

    func testBroxusBytesAndLongFixture() throws {
        let value = ByteFixture(payload: Data(0...9), another: 123)
        let fixture = hex("010000000a00010203040506070809007b00000000000000")
        XCTAssertEqual(try TLCodec.encode(value), fixture)
        XCTAssertEqual(try TLCodec.decode(ByteFixture.self, from: fixture), value)
        XCTAssertEqual(try TLCodec.encode(Data([0, 1, 2, 3]), boxed: false), hex("0400010203000000"))
    }

    func testIntegerEndiannessAndBoundaries() throws {
        XCTAssertEqual(try TLCodec.encode(Int32(-123), boxed: false), hex("85ffffff"))
        XCTAssertEqual(try TLCodec.encode(Int64(-123), boxed: false), hex("85ffffffffffffff"))
        XCTAssertEqual(try TLCodec.encode(UInt64(0x0807_0605_0403_0201), boxed: false), hex("0102030405060708"))
        for value in [Int32.min, -1, 0, 1, Int32.max] {
            XCTAssertEqual(try TLCodec.decode(Int32.self, from: TLCodec.encode(value, boxed: false), boxed: false), value)
        }
        for value in [Int64.min, -1, 0, 1, Int64.max] {
            XCTAssertEqual(try TLCodec.decode(Int64.self, from: TLCodec.encode(value, boxed: false), boxed: false), value)
        }
        for value in [UInt32.min, 1, UInt32.max] {
            XCTAssertEqual(try TLCodec.decode(UInt32.self, from: TLCodec.encode(value, boxed: false), boxed: false), value)
        }
        XCTAssertEqual(try TLCodec.decode(UInt64.self, from: TLCodec.encode(UInt64.max)), UInt64.max)
        XCTAssertEqual(try TLCodec.encode(UInt8(0xff)), Data([0xff]))
        XCTAssertEqual(try TLCodec.decode(Int8.self, from: Data([0xff])), -1)
    }

    func testDoublePreservesIEEEBits() throws {
        XCTAssertEqual(try TLCodec.encode(Double(1.5), boxed: false), hex("000000000000f83f"))
        for bits: UInt64 in [0, 0x8000_0000_0000_0000, 0x7ff0_0000_0000_0000, 0xfff0_0000_0000_0000, 0x7ff8_0000_0000_1234] {
            let encoded = try TLCodec.encode(Double(bitPattern: bits), boxed: false)
            XCTAssertEqual(encoded, try TLCodec.encode(bits, boxed: false))
            XCTAssertEqual(try TLCodec.decode(Double.self, from: encoded, boxed: false).bitPattern, bits)
        }
    }

    func testBooleanAndTrueTags() throws {
        XCTAssertEqual(try TLCodec.encode(true), hex("b5757299"))
        XCTAssertEqual(try TLCodec.encode(false), hex("379779bc"))
        XCTAssertTrue(try TLCodec.decode(Bool.self, from: hex("b5757299")))
        XCTAssertFalse(try TLCodec.decode(Bool.self, from: hex("379779bc")))
        XCTAssertEqual(try TLCodec.encode(TLTrue()), hex("39d3ed3f"))
        XCTAssertEqual(try TLCodec.encode(TLTrue(), boxed: false), Data())
        XCTAssertEqual(try TLCodec.decode(TLTrue.self, from: Data(), boxed: false), TLTrue())
        XCTAssertThrowsError(try TLCodec.encode(true, boxed: false))
        XCTAssertThrowsError(try TLCodec.decode(Bool.self, from: hex("01000000"))) { error in
            XCTAssertEqual(error as? TLCodecError, .unknownConstructor(1))
        }
    }

    func testByteLengthBoundaryPrefixesAndPadding() throws {
        for count in [0, 1, 2, 3, 4, 253, 254, 255, 256, 65_536] {
            let bytes = Data((0..<count).map { UInt8(truncatingIfNeeded: $0) })
            let encoded = try TLCodec.encode(bytes, boxed: false)
            let prefix = count < 254 ? 1 : 4
            let padding = (4 - (prefix + count) % 4) % 4
            XCTAssertEqual(encoded.count, prefix + count + padding)
            if count < 254 {
                XCTAssertEqual(encoded.first, UInt8(count))
            } else {
                XCTAssertEqual(Array(encoded.prefix(4)), [254, UInt8(truncatingIfNeeded: count), UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count >> 16)])
            }
            XCTAssertEqual(encoded.suffix(padding), Data(repeating: 0, count: padding))
            XCTAssertEqual(try TLCodec.decode(Data.self, from: encoded, boxed: false), bytes)
        }
        XCTAssertEqual(try TLCodec.decode(Data.self, from: hex("017b99ff"), boxed: false), Data([123]))
        XCTAssertEqual(try TLCodec.decode(Data.self, from: hex("fe0100007b000000"), boxed: false), Data([123]))
    }

    func testStringsUseUTF8AndRejectInvalidSequences() throws {
        let string = "Привет 🌍"
        XCTAssertEqual(try TLCodec.encode(string, boxed: false), try TLCodec.encode(Data(string.utf8), boxed: false))
        XCTAssertEqual(try TLCodec.decode(String.self, from: TLCodec.encode(string, boxed: false), boxed: false), string)
        XCTAssertThrowsError(try TLCodec.decode(String.self, from: hex("01ff0000"), boxed: false)) { error in
            XCTAssertEqual(error as? TLCodecError, .invalidUTF8)
        }
    }

    func testFixedWidthBytesHaveNoLengthPrefixOrByteReversal() throws {
        let bytes128 = Data(0..<16)
        let bytes256 = Data(0..<32)
        let bytes512 = Data(0..<64)
        XCTAssertEqual(try TLCodec.encode(TLBytes128(bytes128), boxed: false), bytes128)
        XCTAssertEqual(try TLCodec.encode(TLBytes256(bytes256), boxed: false), bytes256)
        XCTAssertEqual(try TLCodec.encode(TLBytes512(bytes512), boxed: false), bytes512)
        XCTAssertEqual(try TLCodec.decode(TLBytes128.self, from: bytes128).data, bytes128)
        XCTAssertEqual(try TLCodec.decode(TLBytes256.self, from: bytes256).data, bytes256)
        XCTAssertEqual(try TLCodec.decode(TLBytes512.self, from: bytes512).data, bytes512)
        XCTAssertThrowsError(try TLBytes128(Data(repeating: 0, count: 15)))
        XCTAssertThrowsError(try TLBytes256(Data(repeating: 0, count: 33)))
        XCTAssertThrowsError(try TLBytes512(Data(repeating: 0, count: 63)))
    }

    func testVectorsWriteCountAndExplicitElementRepresentation() throws {
        let values = [EmptyFixture(), EmptyFixture()]
        var bareWriter = TLWriter()
        try bareWriter.writeVector(values, elementBoxed: false)
        XCTAssertEqual(bareWriter.data, hex("02000000"))
        var boxedWriter = TLWriter()
        try boxedWriter.writeVector(values, elementBoxed: true)
        XCTAssertEqual(boxedWriter.data, hex("020000000300000003000000"))
        var bareReader = TLReader(data: bareWriter.data)
        XCTAssertEqual(try bareReader.readVector(EmptyFixture.self, elementBoxed: false), values)
        var boxedReader = TLReader(data: boxedWriter.data)
        XCTAssertEqual(try boxedReader.readVector(EmptyFixture.self, elementBoxed: true), values)
        XCTAssertEqual(try TLCodec.decode([EmptyFixture].self, from: boxedWriter.data), values)
        XCTAssertEqual(try TLCodec.decode(TLBareVector<EmptyFixture>.self, from: bareWriter.data).values, values)
        XCTAssertEqual(try TLCodec.encode(TLBoxedVector(values)), boxedWriter.data)
        var trueReader = TLReader(data: hex("04000000"))
        XCTAssertEqual(try trueReader.readVector(TLTrue.self, elementBoxed: false).count, 4)
    }

    func testNestedVectorsKeepInnerElementBoxing() throws {
        let values = [TLBareVector([EmptyFixture(), EmptyFixture()]), TLBareVector([])]
        var writer = TLWriter()
        try writer.writeVector(values, elementBoxed: false)
        XCTAssertEqual(writer.data, hex("020000000200000000000000"))
        var reader = TLReader(data: writer.data)
        XCTAssertEqual(try reader.readVector(TLBareVector<EmptyFixture>.self, elementBoxed: false), values)
    }

    func testTruncatedInputsFailAtEveryByteBoundary() throws {
        let fixture = hex("010000000a00010203040506070809007b00000000000000")
        for count in 0..<fixture.count {
            XCTAssertThrowsError(try TLCodec.decode(ByteFixture.self, from: Data(fixture.prefix(count)))) { error in
                guard case .unexpectedEnd = error as? TLCodecError else {
                    return XCTFail("Unexpected error at prefix \(count): \(error)")
                }
            }
        }
        for data in [hex("fe"), hex("fe0100"), hex("0401020304"), hex("04010203040000")] {
            XCTAssertThrowsError(try TLCodec.decode(Data.self, from: data, boxed: false))
        }
        var reader = TLReader(data: hex("020000000102030405060708"))
        XCTAssertThrowsError(try reader.readVector(UInt64.self, elementBoxed: false))
    }

    func testLengthAndAllocationLimits() throws {
        var negative = TLReader(data: hex("ffffffff"))
        XCTAssertThrowsError(try negative.readVector(UInt32.self, elementBoxed: false)) { error in
            XCTAssertEqual(error as? TLCodecError, .invalidLength(-1))
        }
        var vector = TLReader(data: hex("ffffffff"))
        XCTAssertThrowsError(try vector.readRaw(count: -1))
        var limitedVector = TLReader(data: hex("03000000"), limits: .init(maxVectorCount: 2))
        XCTAssertThrowsError(try limitedVector.readVector(TLTrue.self, elementBoxed: false)) { error in
            guard case .limitExceeded = error as? TLCodecError else { return XCTFail("\(error)") }
        }
        let encoded = try TLCodec.encode(Data([1, 2, 3, 4]), boxed: false)
        XCTAssertThrowsError(try TLCodec.decode(Data.self, from: encoded, limits: .init(maxBytesLength: 3))) { error in
            guard case .limitExceeded = error as? TLCodecError else { return XCTFail("\(error)") }
        }
    }

    func testDepthLimitAndRecoveryAfterFailure() throws {
        var value = RecursiveFixture.leaf
        for _ in 0..<12 { value = .nested(value) }
        let encoded = try TLCodec.encode(value)
        XCTAssertEqual(try TLCodec.decode(RecursiveFixture.self, from: encoded), value)
        var reader = TLReader(data: encoded, limits: .init(maxDepth: 8))
        XCTAssertThrowsError(try reader.read(RecursiveFixture.self)) { error in
            guard case .limitExceeded = error as? TLCodecError else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(reader.depth, 0)
        XCTAssertNoThrow(try reader.withDepth { _ in 1 })
    }

    func testConstructorMismatchAndTrailingBytes() throws {
        XCTAssertThrowsError(try TLCodec.decode(EmptyFixture.self, from: hex("01000000"))) { error in
            XCTAssertEqual(error as? TLCodecError, .invalidConstructor(expected: 3, actual: 1))
        }
        let fixture = hex("03000000ff")
        XCTAssertThrowsError(try TLCodec.decode(EmptyFixture.self, from: fixture)) { error in
            XCTAssertEqual(error as? TLCodecError, .trailingBytes(1))
        }
        XCTAssertEqual(try TLCodec.decode(EmptyFixture.self, from: fixture, requireExhaustion: false), EmptyFixture())
        let prefix = try TLCodec.decodePrefix(EmptyFixture.self, from: fixture)
        XCTAssertEqual(prefix.value, EmptyFixture())
        XCTAssertEqual(prefix.consumed, 4)
    }

    func testDataSlicesWithNonzeroIndices() throws {
        let fixture = hex("010000000a00010203040506070809007b00000000000000")
        let full = Data([0xff]) + fixture
        let sliced = full[1...]
        XCTAssertEqual(try TLCodec.decode(ByteFixture.self, from: sliced), ByteFixture(payload: Data(0...9), another: 123))
        var reader = TLReader(data: sliced)
        _ = try reader.read(UInt32.self, boxed: false)
        XCTAssertEqual(reader.remainingData, Data(fixture.dropFirst(4)))
    }

    func testRegistryDynamicObjectsAndDuplicateErrors() throws {
        var registry = TLRegistry()
        try registry.register(ByteFixture.self, id: 1, name: "test.bytes")
        try registry.register(EmptyFixture.self, id: 3, name: "test.empty")
        XCTAssertEqual(registry.constructorIDs, [1, 3, TLTrue.constructorID, Bool.trueConstructorID, Bool.falseConstructorID])
        XCTAssertEqual(registry.name(for: 1), "test.bytes")
        XCTAssertEqual(registry.id(named: "test.empty"), 3)
        let value = ByteFixture(payload: Data([1, 2, 3]), another: 42)
        let data = try TLCodec.encode(value)
        let dynamic = try TLCodec.decode(TLObject.self, from: data, registry: registry)
        XCTAssertEqual(dynamic.cast(to: ByteFixture.self), value)
        XCTAssertNil(dynamic.cast(to: EmptyFixture.self))
        XCTAssertEqual(try dynamic.constructorID(), 1)
        XCTAssertEqual(try TLCodec.encode(dynamic), data)
        XCTAssertEqual(dynamic, TLObject(value))
        XCTAssertEqual(TLObject(dynamic), dynamic)
        XCTAssertThrowsError(try TLCodec.encode(dynamic, boxed: false)) { error in
            XCTAssertEqual(error as? TLCodecError, .unsupported("bare dynamic Object"))
        }
        XCTAssertThrowsError(try registry.register(EmptyFixture.self, id: 1, name: "another")) { error in
            XCTAssertEqual(error as? TLCodecError, .duplicateConstructor(1))
        }
        XCTAssertThrowsError(try registry.register(EmptyFixture.self, id: 7, name: "test.empty")) { error in
            XCTAssertEqual(error as? TLCodecError, .duplicateName("test.empty"))
        }
        XCTAssertThrowsError(try TLCodec.decode(TLObject.self, from: hex("04000000"), registry: registry)) { error in
            XCTAssertEqual(error as? TLCodecError, .unknownConstructor(4))
        }
        XCTAssertThrowsError(try TLCodec.decode(TLObject.self, from: Data(), boxed: false, registry: registry))
    }

    func testDynamicEqualityWhenEncodingFails() {
        let object = TLObject(UnencodableFixture())
        XCTAssertEqual(object, object)
        XCTAssertEqual(TLObject(object), object)
        XCTAssertNotEqual(TLObject(UnencodableFixture()), object)
    }

    func testDynamicBuiltinsUseDefaultRegistry() throws {
        for (fixture, value) in [("b5757299", true), ("379779bc", false)] {
            let bytes = hex(fixture)
            let object = try TLCodec.decode(TLObject.self, from: bytes)
            XCTAssertEqual(object.cast(to: Bool.self), value)
            XCTAssertEqual(try TLCodec.encode(object), bytes)
        }
        let bytes = hex("39d3ed3f")
        let object = try TLCodec.decode(TLObject.self, from: bytes)
        XCTAssertEqual(object.cast(to: TLTrue.self), TLTrue())
        XCTAssertEqual(try TLCodec.encode(object), bytes)
    }

    func testLengthPrefixedObjectUsesSignedByteCountWithoutPadding() throws {
        var registry = TLRegistry()
        try registry.register(EmptyFixture.self, id: 3, name: "test.empty")
        let value = TLLengthPrefixed(TLObject(EmptyFixture()))
        let fixture = hex("0400000003000000")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), fixture)
        XCTAssertEqual(try TLCodec.decode(TLLengthPrefixed<TLObject>.self, from: fixture, registry: registry), value)
        XCTAssertThrowsError(try TLCodec.decode(TLLengthPrefixed<TLObject>.self, from: hex("ffffffff"), registry: registry)) { error in
            XCTAssertEqual(error as? TLCodecError, .invalidLength(-1))
        }
        XCTAssertThrowsError(try TLCodec.decode(TLLengthPrefixed<TLObject>.self, from: hex("0500000003000000ff"), registry: registry)) { error in
            XCTAssertEqual(error as? TLCodecError, .trailingBytes(1))
        }
        XCTAssertThrowsError(try TLCodec.decode(TLLengthPrefixed<TLObject>.self, from: fixture, registry: registry, limits: .init(maxBytesLength: 3)))
    }

    func testLengthPrefixedObjectRetainsDepthLimit() throws {
        let value = TLLengthPrefixed(TLLengthPrefixed(TLLengthPrefixed(EmptyFixture())))
        let data = try TLCodec.encode(value)
        XCTAssertThrowsError(try TLCodec.decode(type(of: value), from: data, limits: .init(maxDepth: 3))) { error in
            guard case .limitExceeded = error as? TLCodecError else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(try TLCodec.decode(type(of: value), from: data), value)
    }

    func testStrictAndPrefixBundles() throws {
        var registry = TLRegistry()
        try registry.register(EmptyFixture.self, id: 3, name: "test.empty")
        let expected = [TLObject(EmptyFixture()), TLObject(EmptyFixture())]
        let valid = hex("0300000003000000")
        XCTAssertEqual(try TLCodec.decodeBundle(from: valid, registry: registry), expected)
        XCTAssertThrowsError(try TLCodec.decodeBundle(from: valid + Data([0xff]), registry: registry))
        let result = try TLCodec.decodeBundlePrefix(from: valid + Data([0xff]), registry: registry)
        XCTAssertEqual(result.values, expected)
        XCTAssertEqual(result.consumed, 8)
        XCTAssertThrowsError(try TLCodec.decodeBundlePrefix(from: Data([0xff]), registry: registry))
        XCTAssertEqual(try TLCodec.decodeBundle(from: Data(), registry: registry), [])
    }
}

private struct PrimitiveFixture: TLConstructor, Equatable {
    static let constructorID: UInt32 = 0xffff_ffff
    let item: UInt32
    let what: Bool
    let another: UInt32
    static func readBare(from reader: inout TLReader) throws -> Self {
        Self(item: try reader.read(UInt32.self, boxed: false), what: try reader.read(Bool.self), another: try reader.read(UInt32.self, boxed: false))
    }
    func writeBare(to writer: inout TLWriter) throws {
        try writer.write(item, boxed: false)
        try writer.write(what)
        try writer.write(another, boxed: false)
    }
}

private struct ByteFixture: TLConstructor, Equatable {
    static let constructorID: UInt32 = 1
    let payload: Data
    let another: UInt64
    static func readBare(from reader: inout TLReader) throws -> Self {
        Self(payload: try reader.read(Data.self, boxed: false), another: try reader.read(UInt64.self, boxed: false))
    }
    func writeBare(to writer: inout TLWriter) throws {
        try writer.write(payload, boxed: false)
        try writer.write(another, boxed: false)
    }
}

private struct EmptyFixture: TLConstructor, Equatable {
    static let constructorID: UInt32 = 3
    static func readBare(from reader: inout TLReader) throws -> Self { .init() }
    func writeBare(to writer: inout TLWriter) throws {}
}

private indirect enum RecursiveFixture: TLSerializable, Equatable {
    case leaf
    case nested(Self)
    static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        let id = try reader.read(UInt32.self, boxed: false)
        switch id {
        case 0: return .leaf
        case 1: return .nested(try reader.read(Self.self))
        default: throw TLCodecError.unknownConstructor(id)
        }
    }
    func write(to writer: inout TLWriter, boxed: Bool) throws {
        switch self {
        case .leaf: try writer.write(UInt32(0), boxed: false)
        case let .nested(child):
            try writer.write(UInt32(1), boxed: false)
            try writer.write(child)
        }
    }
}

private struct UnencodableFixture: TLBoxedSerializable {
    static func read(from reader: inout TLReader, boxed: Bool) throws -> Self {
        throw TLCodecError.unsupported("fixture")
    }
    func write(to writer: inout TLWriter, boxed: Bool) throws {
        throw TLCodecError.unsupported("fixture")
    }
}

private func hex(_ value: String) -> Data {
    var bytes: [UInt8] = []
    var index = value.startIndex
    while index < value.endIndex {
        let next = value.index(index, offsetBy: 2)
        bytes.append(UInt8(value[index..<next], radix: 16)!)
        index = next
    }
    return Data(bytes)
}
