import EverTL
import EverTLCodegen
import Foundation
import XCTest

final class GeneratedFixtureTests: XCTestCase {
    private var record: FixtureRecordConstructor {
        .init(index: 0x2468, enabled: true, checksum: 0x1357)
    }

    private var marker: FixtureMarkerConstructor {
        .init(chain: -1, epoch: .max, offset: 7, digest: TLBytes256())
    }

    func testGeneratedStructMatchesExpectedWireBytes() throws {
        let bytes = fixtureHex("028fba1968240000b575729957130000")
        XCTAssertEqual(try TLCodec.encode(record), bytes)
        XCTAssertEqual(try TLCodec.decode(FixtureRecordConstructor.self, from: bytes), record)
        XCTAssertEqual(try TLCodec.encode(FixtureRecord.fixtureRecord(record)), bytes)
        XCTAssertEqual(try TLCodec.decode(FixtureRecord.self, from: bytes), .fixtureRecord(record))
    }

    func testGeneratedBytesAndSignedLongMatchExpectedWireBytes() throws {
        let value = FixtureBufferConstructor(payload: Data([9, 8, 7, 6, 5]), revision: -2)
        let bytes = fixtureHex("44f01ab60509080706050000feffffffffffffff")
        XCTAssertEqual(try TLCodec.encode(value), bytes)
        XCTAssertEqual(try TLCodec.decode(FixtureBufferConstructor.self, from: bytes), value)
    }

    func testBit31AndZeroPayloadTrueMatchExpectedWireBytes() throws {
        let value = FixtureFlagsConstructor(token: 0x2468, urgent: true, ready: false)
        let bytes = fixtureHex("0300008068240000379779bc")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), bytes)
        var canonical = value
        canonical.mask = 0x8000_0003
        XCTAssertEqual(try TLCodec.decode(FixtureFlagsConstructor.self, from: bytes, boxed: false), canonical)
        XCTAssertEqual(try TLCodec.encode(FixtureFlagsConstructor(), boxed: false), fixtureHex("00000000"))
    }

    func testSharedFlagBitRequiresBothFieldsAndPreservesUnknownBits() throws {
        XCTAssertThrowsError(try TLCodec.encode(FixtureSharedConstructor(left: -7))) { error in
            guard case .inconsistentFlags = error as? TLCodecError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let value = FixtureSharedConstructor(mask: 0x8000_0000, left: -7, right: 42)
        let bytes = fixtureHex("04000080f9ffffff2a000000")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), bytes)
        var canonical = value
        canonical.mask |= 4
        XCTAssertEqual(try TLCodec.decode(FixtureSharedConstructor.self, from: bytes, boxed: false), canonical)
    }

    func testGeneratedVectorsKeepBareAndBoxedElementsDistinct() throws {
        let value = FixtureVectorsConstructor(bare: [record], boxed: [.fixtureRecord(record)])
        let bytes = fixtureHex("0100000068240000b57572995713000001000000028fba1968240000b575729957130000")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), bytes)
        XCTAssertEqual(try TLCodec.decode(FixtureVectorsConstructor.self, from: bytes, boxed: false), value)
    }

    func testGeneratedNestedVectors() throws {
        let value = FixtureNestedConstructor(values: [TLBareVector([4, -2]), TLBareVector([])])
        let bytes = fixtureHex("020000000200000004000000feffffff00000000")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), bytes)
        XCTAssertEqual(try TLCodec.decode(FixtureNestedConstructor.self, from: bytes, boxed: false), value)
    }

    func testGeneratedRegistryDecodesObjectAndGenericRPC() throws {
        let registry = try EverTLSchema.makeRegistry()
        let value = FixtureObjectConstructor(value: TLObject(FixtureRecord.fixtureRecord(record)))
        let decoded = try TLCodec.decode(
            FixtureObjectConstructor.self, from: TLCodec.encode(value), registry: registry
        )
        XCTAssertEqual(decoded.value.cast(to: FixtureRecordConstructor.self), record)
        XCTAssertEqual(decoded, value)

        let request = FixtureInvokeRequest(query: FixtureGetRecordRequest())
        let reply: FixtureInvokeRequest<FixtureGetRecordRequest>.Reply = .fixtureRecord(record)
        XCTAssertEqual(try TLCodec.decode(
            FixtureInvokeRequest<FixtureGetRecordRequest>.Reply.self,
            from: TLCodec.encode(reply), boxed: FixtureInvokeRequest<FixtureGetRecordRequest>.replyBoxed
        ), reply)
        let dynamic = try TLCodec.decode(TLObject.self, from: TLCodec.encode(request), registry: registry)
        let invocation = try XCTUnwrap(dynamic.cast(to: FixtureInvokeRequest<TLObject>.self))
        XCTAssertNotNil(invocation.query.cast(to: FixtureGetRecordRequest.self))
        XCTAssertEqual(try TLCodec.encode(dynamic), try TLCodec.encode(request))
    }

    func testGeneratedLengthPrefixedObject() throws {
        let value = FixturePrefixedConstructor(value: TLLengthPrefixed(TLObject(record)))
        let bytes = fixtureHex("10000000028fba1968240000b575729957130000")
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), bytes)
        XCTAssertEqual(try TLCodec.decode(
            FixturePrefixedConstructor.self, from: bytes, boxed: false, registry: EverTLSchema.makeRegistry()
        ), value)
    }

    func testSecureStringPreservesBinaryPayload() throws {
        let value = FixtureSecretsConstructor(text: Data([0xfe, 0xc0]), bytes: Data([4, 3, 2, 1]))
        XCTAssertEqual(try TLCodec.encode(value, boxed: false), fixtureHex("02fec0000404030201000000"))
        XCTAssertEqual(try TLCodec.decode(FixtureSecretsConstructor.self, from: TLCodec.encode(value)), value)
    }

    func testSwiftKeywordFieldsCompileAndRoundTrip() throws {
        let value = FixtureKeywordsConstructor(self: -2, class: 21)
        XCTAssertEqual(try TLCodec.decode(FixtureKeywordsConstructor.self, from: TLCodec.encode(value)), value)
    }

    func testModeFlagsPreserveUnknownBitsAndUseBarePayload() throws {
        let value = FixtureLookupRequest(mode: 0x8000_0000, marker: marker, timestamp: 100)
        let bytes = try TLCodec.encode(value)
        XCTAssertEqual(bytes.count, 4 + 4 + 48 + 8)
        XCTAssertEqual(bytes.subdata(in: 4..<8), fixtureHex("02000080"))
        XCTAssertEqual(bytes.subdata(in: 8..<56), try TLCodec.encode(marker, boxed: false))
        XCTAssertEqual(Data(bytes.suffix(8)), fixtureHex("6400000000000000"))
        var canonical = value
        canonical.mode |= 2
        XCTAssertEqual(try TLCodec.decode(FixtureLookupRequest.self, from: bytes), canonical)
    }

    func testCountFieldIsIndependentFromOptionalModeFlags() throws {
        let value = FixtureListRequest(
            marker: marker, mode: 0x0080_0000, count: 9, descending: true, include_hash: true
        )
        let bytes = try TLCodec.encode(value)
        XCTAssertEqual(bytes.count, 4 + 48 + 8)
        XCTAssertEqual(Data(bytes.suffix(8)), fixtureHex("6000800009000000"))
        var canonical = value
        canonical.mode |= 0x60
        XCTAssertEqual(try TLCodec.decode(FixtureListRequest.self, from: bytes), canonical)
        let reply: FixtureListRequest.Reply = TLBoxedVector([FixtureRecord.fixtureRecord(record)])
        XCTAssertEqual(try TLCodec.decode(
            FixtureListRequest.Reply.self, from: TLCodec.encode(reply), boxed: FixtureListRequest.replyBoxed
        ), reply)
    }

    func testByteSizedMaskAndUnsignedFields() throws {
        let value = FixtureSmallMaskConstructor(bits: 1, marker: marker)
        let bytes = try TLCodec.encode(value, boxed: false)
        XCTAssertEqual(bytes.count, 1 + 48)
        XCTAssertEqual(bytes.first, 0x81)
        var canonical = value
        canonical.bits |= 0x80
        XCTAssertEqual(try TLCodec.decode(FixtureSmallMaskConstructor.self, from: bytes, boxed: false), canonical)

        let wide = FixtureWideConstructor(maximum: .max, minimum: .min, extra: .max)
        let expected = fixtureHex("ffffffffffffffff0000000000000080ffffffffffffffff")
        XCTAssertEqual(try TLCodec.encode(wide, boxed: false), expected)
        XCTAssertEqual(try TLCodec.decode(FixtureWideConstructor.self, from: expected, boxed: false), wide)
    }

    func testNamespaceCollisionsHaveDistinctCompiledTypes() throws {
        let namespaced = Project_Token.projectToken(.init(value: -3))
        let global = ProjectToken.projectToken(.init(value: Data([4, 2])))
        XCTAssertEqual(try TLCodec.decode(Project_Token.self, from: TLCodec.encode(namespaced)), namespaced)
        XCTAssertEqual(try TLCodec.decode(ProjectToken.self, from: TLCodec.encode(global)), global)
        XCTAssertNotEqual(Project_TokenConstructor.constructorID, ProjectTokenConstructor.constructorID)
    }

    func testRegistryContainsEveryTagAndDisambiguatesRepeatedBareNames() throws {
        let registry = try EverTLSchema.makeRegistry()
        let url = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent("Fixtures/generated.tl")
        let schema = try TLParser.parse(String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(EverTLSchema.constructorCount, schema.constructors.count)
        XCTAssertEqual(Set(registry.constructorIDs), Set(schema.constructors.map(\.id)).union([
            0x9972_75b5, 0xbc79_9737, 0x3fedd339
        ]))
        XCTAssertEqual(registry.id(named: "payload.entry as payload.Entry"), PayloadEntryAsPayloadEntryConstructor.constructorID)
        XCTAssertEqual(registry.id(named: "payload.entry as model.Entry"), PayloadEntryAsModelEntryConstructor.constructorID)
        let first = PayloadEntryAsPayloadEntryConstructor(key: TLBytes256())
        let second = PayloadEntryAsModelEntryConstructor(version: -7)
        let firstObject = try TLCodec.decode(TLObject.self, from: TLCodec.encode(first), registry: registry)
        let secondObject = try TLCodec.decode(TLObject.self, from: TLCodec.encode(second), registry: registry)
        XCTAssertEqual(firstObject.cast(to: PayloadEntryAsPayloadEntryConstructor.self), first)
        XCTAssertEqual(secondObject.cast(to: PayloadEntryAsModelEntryConstructor.self), second)
    }

    func testTypedRPCReplyAndDynamicFunction() throws {
        let request = FixturePingRequest(nonce: -7)
        let reply: FixturePingRequest.Reply = .fixturePong(.init(nonce: -7))
        XCTAssertEqual(try TLCodec.decode(
            FixturePingRequest.Reply.self, from: TLCodec.encode(reply), boxed: FixturePingRequest.replyBoxed
        ), reply)
        let dynamic = try TLCodec.decode(
            TLObject.self, from: TLCodec.encode(request), registry: EverTLSchema.makeRegistry()
        )
        XCTAssertEqual(dynamic.cast(to: FixturePingRequest.self), request)
    }

    func testCompiledFixtureSourceMatchesGenerator() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent("Fixtures/generated.tl")
        let generated = try TLSwiftGenerator.generate(schema: TLParser.parse(
            String(contentsOf: fixtureURL, encoding: .utf8)
        ))
        let checkedIn = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("GeneratedFixtures.swift")
        XCTAssertEqual(generated, try String(contentsOf: checkedIn, encoding: .utf8))
    }
}

func fixtureHex(_ source: String) -> Data {
    let bytes = Array(source.utf8)
    return Data(stride(from: 0, to: bytes.count, by: 2).map {
        UInt8(String(decoding: bytes[$0..<($0 + 2)], as: UTF8.self), radix: 16)!
    })
}
