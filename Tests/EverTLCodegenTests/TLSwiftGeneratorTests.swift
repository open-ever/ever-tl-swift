import Foundation
import XCTest
@testable import EverTLCodegen

final class TLSwiftGeneratorTests: XCTestCase {
    func testConstructorAndBoxedResultHaveDistinctWireTypes() throws {
        let source = try generate("lab.endpoint.socket channel:int capacity:int = lab.Endpoint;")
        XCTAssertTrue(source.contains("public struct LabEndpointSocketConstructor: TLConstructor, Equatable, Sendable"))
        XCTAssertTrue(source.contains("public indirect enum LabEndpoint: TLBoxedSerializable, Equatable, Sendable"))
        XCTAssertTrue(source.contains("case labEndpointSocket(LabEndpointSocketConstructor)"))
        XCTAssertTrue(source.contains("public var channel: Swift.Int32"))
        XCTAssertTrue(source.contains("public static var constructorID: Swift.UInt32"))
        XCTAssertTrue(source.contains("public enum EverTLSchema"))
    }

    func testBareAndBoxedVectorElementTypes() throws {
        let source = try generate("""
        item value:int = Item;
        list bare:(vector item) boxed:(vector Item) = List;
        """)
        XCTAssertTrue(source.contains("public var bare: [ItemConstructor]"))
        XCTAssertTrue(source.contains("public var boxed: [Item]"))
        XCTAssertTrue(source.contains("reader.readVector(ItemConstructor.self, elementBoxed: false)"))
        XCTAssertTrue(source.contains("reader.readVector(Item.self, elementBoxed: true)"))
    }

    func testNestedVectorsPreserveInnerElementBoxing() throws {
        let source = try generate("nested values:(vector (vector int)) = Nested;")
        XCTAssertTrue(source.contains("public var values: [TLBareVector<Swift.Int32>]"))
        XCTAssertTrue(source.contains("reader.readVector(TLBareVector<Swift.Int32>.self, elementBoxed: false)"))
    }

    func testFlagMasksPreserveUnknownBitsAndValidateSharedPresence() throws {
        let source = try generate("sample flags:# a:flags.0?int b:flags.0?int enabled:flags.31?true = Sample;")
        XCTAssertTrue(source.contains("public var flags: Swift.UInt32"))
        XCTAssertTrue(source.contains("public var enabled: Swift.Bool"))
        XCTAssertTrue(source.contains("var _tlMask0 = self.flags"))
        XCTAssertTrue(source.contains("guard (self.a != nil) == (self.b != nil)"))
        XCTAssertTrue(source.contains("throw TLCodecError.inconsistentFlags"))
        XCTAssertTrue(source.contains("Swift.UInt32(1) << 31"))
        XCTAssertFalse(source.contains("writer.write(self.enabled"))
    }

    func testByteMaskWidthIsValidated() throws {
        let source = try generate("valid flags:uint8 data:flags.7?bytes = Valid;")
        XCTAssertTrue(source.contains("Swift.UInt8(1) << 7"))
        XCTAssertThrowsError(try generate("invalid flags:uint8 data:flags.8?bytes = Invalid;")) { error in
            guard case TLGeneratorError.invalidFlags(let message) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertTrue(message.contains("8-bit"))
        }
    }

    func testMissingOrLaterMaskIsRejected() throws {
        XCTAssertThrowsError(try generate("sample value:flags.0?int = Sample;"))
        XCTAssertThrowsError(try generate("sample value:flags.0?int flags:# = Sample;"))
        XCTAssertThrowsError(try generate("sample flags:bytes value:flags.0?int = Sample;"))
    }

    func testGenericRPCReplyUsesNestedQueryReply() throws {
        let source = try generate("---functions--- invoke {X:Type} query:!X = X;")
        XCTAssertTrue(source.contains("public struct InvokeRequest<X: TLFunction>: TLConstructor, TLFunction, Sendable"))
        XCTAssertTrue(source.contains("public typealias Reply = X.Reply"))
        XCTAssertTrue(source.contains("public static var replyBoxed: Swift.Bool { X.replyBoxed }"))
        XCTAssertTrue(source.contains("extension InvokeRequest: Equatable where X: Equatable {}"))
        XCTAssertTrue(source.contains("registry.register(InvokeRequest<TLObject>.self"))
        let explicitReply = try generate("---functions--- invoke {X:Type} query:!X = !X;")
        XCTAssertTrue(explicitReply.contains("public typealias Reply = X.Reply"))
    }

    func testTypedRPCReplyAndVectorReply() throws {
        let source = try generate("item = Item; ---functions--- get = Item; list = (vector item);")
        XCTAssertTrue(source.contains("public typealias Reply = Item"))
        XCTAssertTrue(source.contains("public typealias Reply = TLBareVector<ItemConstructor>"))
    }

    func testBuiltinFilteringAndSecureBytes() throws {
        let source = try generate("""
        int ? = Int;
        boolFalse = Bool;
        boolTrue = Bool;
        vector {t:Type} # [ t ] = Vector t;
        secureString = SecureString;
        secureBytes = SecureBytes;
        key text:secureString bytes:secureBytes bool:Bool = Key;
        """)
        XCTAssertFalse(source.contains("struct BoolTrueConstructor"))
        XCTAssertFalse(source.contains("struct VectorConstructor"))
        XCTAssertTrue(source.contains("public var text: Foundation.Data"))
        XCTAssertTrue(source.contains("public var bytes: Foundation.Data"))
        XCTAssertTrue(source.contains("reader.read(Swift.Bool.self, boxed: true)"))
        let trueReply = try generate("---functions--- ack = True;")
        XCTAssertTrue(trueReply.contains("public typealias Reply = Swift.Bool"))
        XCTAssertTrue(trueReply.contains("public static var replyBoxed: Swift.Bool { true }"))
        let integerAliases = try generate("aliases tiny:byte number:uint large:ulong = Aliases;")
        XCTAssertTrue(integerAliases.contains("public var tiny: Swift.UInt8"))
        XCTAssertTrue(integerAliases.contains("public var number: Swift.UInt32"))
        XCTAssertTrue(integerAliases.contains("public var large: Swift.UInt64"))
    }

    func testDynamicAndLengthPrefixedObject() throws {
        let source = try generate("holder object:Object prefix:lengthPrefixedTypedObject typed:(lengthPrefixedTypedObject Object) = Holder;")
        XCTAssertTrue(source.contains("public var object: TLObject"))
        XCTAssertTrue(source.contains("public var prefix: TLLengthPrefixed<TLObject>"))
        XCTAssertTrue(source.contains("public var typed: TLLengthPrefixed<TLObject>"))
    }

    func testConfigurationDecodesUpstreamKeysAndReplacesDirectStrings() throws {
        let config = try JSONDecoder().decode(TLGeneratorConfiguration.self, from: Data("""
        {"exclude_types":["unused"],"need_box":["Recursive"],"need_determiner":[],"replace_with_bytes":["data"],"additional_derives":{}}
        """.utf8))
        let schema = try TLParser.parse("unused = Unused; data value:string strings:(vector string) = Data;")
        let source = try TLSwiftGenerator.generate(schema: schema, configuration: config)
        XCTAssertFalse(source.contains("UnusedConstructor"))
        XCTAssertTrue(source.contains("public var value: Foundation.Data"))
        XCTAssertTrue(source.contains("public var strings: [Swift.String]"))
        XCTAssertEqual(config.moduleName, "EverTL")
    }

    func testUnsupportedConfigurationHasActionableDiagnostic() throws {
        XCTAssertThrowsError(try TLSwiftGenerator.generate(schema: .init(constructors: []), configuration: .init(additionalDerives: ["Item": ["Default"]])))
        XCTAssertThrowsError(try TLSwiftGenerator.generate(schema: .init(constructors: []), configuration: .init(needDeterminer: ["Other"])))
        XCTAssertThrowsError(try TLSwiftGenerator.generate(schema: .init(constructors: []), configuration: .init(moduleName: "EverTL; injected")))
    }

    func testIdenticalDuplicatesAreRemovedAndConflictsRejected() throws {
        let parsed = try TLParser.parse("item value:int = Item;")
        let duplicate = TLSchema(constructors: parsed.constructors + parsed.constructors)
        let source = try TLSwiftGenerator.generate(schema: duplicate)
        XCTAssertEqual(source.components(separatedBy: "public struct ItemConstructor").count - 1, 1)
        XCTAssertThrowsError(try generate("item value:int = Item; item value:long = Item;"))
        XCTAssertThrowsError(try generate("first#12345678 = First; second#12345678 = Second;"))
    }

    func testSwiftNameCollisionsAreRejected() throws {
        XCTAssertThrowsError(try generate("one_name = First; one__name = Second;"))
        XCTAssertThrowsError(try generate("one = ns_Thing; two = ns__Thing;"))
        for name in ["Swift", "Foundation", "Sendable", "Equatable", "Self", "Any", "_"] {
            XCTAssertThrowsError(try generate("item = \(name);"))
            XCTAssertThrowsError(try generate("---functions--- invoke {\(name):Type} query:!\(name) = \(name);"))
        }
    }

    func testNamespaceCollisionsProduceDistinctTypes() throws {
        let source = try generate("project.token = project.Token; projectToken = ProjectToken;")
        XCTAssertTrue(source.contains("public indirect enum Project_Token"))
        XCTAssertTrue(source.contains("public indirect enum ProjectToken"))
        XCTAssertTrue(source.contains("public struct Project_TokenConstructor"))
        XCTAssertTrue(source.contains("public struct ProjectTokenConstructor"))
    }

    func testSameBareNameWithDifferentResultsHasDistinctPayloads() throws {
        let source = try generate("payload.entry key:int256 = payload.Entry; payload.entry version:int32 = model.Entry;")
        XCTAssertTrue(source.contains("public struct PayloadEntryAsPayloadEntryConstructor"))
        XCTAssertTrue(source.contains("public struct PayloadEntryAsModelEntryConstructor"))
        XCTAssertTrue(source.contains("name: \"payload.entry as payload.Entry\""))
        XCTAssertThrowsError(try generate("payload.entry key:int256 = payload.Entry; payload.entry version:int32 = model.Entry; holder id:payload.entry = Holder;"))
    }

    func testLowercaseResultNameResolvesUppercaseRPCReply() throws {
        let source = try generate("model.receipt value:int = model.receipt; ---functions--- model.getReceipt = model.Receipt;")
        XCTAssertTrue(source.contains("public indirect enum ModelReceipt"))
        XCTAssertTrue(source.contains("public typealias Reply = ModelReceipt"))
    }

    func testUnsupportedSyntaxProducesDiagnosticInsteadOfInvalidSource() throws {
        XCTAssertThrowsError(try generate("repeatItem count:# [ value:int ] = RepeatItem;"))
        XCTAssertThrowsError(try generate("custom value:(container int) = Custom;"))
        XCTAssertThrowsError(try generate("generic {X:Type} value:!X = Generic;"))
        XCTAssertThrowsError(try generate("unknown value:Missing = Unknown;"))
        XCTAssertThrowsError(try generate("node flags:# next:flags.0?node = Node;"))
        XCTAssertNoThrow(try generate("node flags:# next:flags.0?Node = Node;"))
    }

    func testSyntheticSchemaGeneratesDeterministically() throws {
        let directory = try XCTUnwrap(Bundle.module.resourceURL?.appendingPathComponent("Fixtures"))
        let text = try String(contentsOf: directory.appendingPathComponent("model.tl"), encoding: .utf8)
        let schema = try TLParser.parse(text)
        let first = try TLSwiftGenerator.generate(schema: schema)
        let reversed = try TLSwiftGenerator.generate(schema: .init(constructors: schema.constructors.reversed()))
        XCTAssertEqual(first, reversed)
        XCTAssertTrue(first.contains("public struct ModelEntryConstructor"))
        XCTAssertTrue(first.contains("public struct ModelSmallConstructor"))
        XCTAssertTrue(first.contains("public indirect enum ModelTree"))
        XCTAssertTrue(first.contains("public indirect enum Model_Token"))
        XCTAssertTrue(first.contains("public indirect enum ModelToken"))
    }

    private func generate(_ text: String) throws -> String {
        try TLSwiftGenerator.generate(schema: TLParser.parse(text))
    }
}
