import Foundation
import XCTest
@testable import EverTLCodegen

final class TLParserTests: XCTestCase {
    func testEmptySchemaAndComments() throws {
        let schema = try TLParser.parse("\n// Empty schema\n/* Nothing to parse */\n")
        XCTAssertEqual(schema, TLSchema(constructors: []))
    }

    func testBuiltinsAndKnownConstructorIDs() throws {
        let schema = try TLParser.parse("""
        int ? = Int;
        boolTrue = Bool;
        boolFalse = Bool;
        fixture.pulse = fixture.Pulse;
        """)
        XCTAssertEqual(schema.constructors.map(\.id), [0xe6fd_f69c, 0x9972_75b5, 0xbc79_9737, 0x8d3b_ea1a])
        XCTAssertEqual(schema.constructors.map(\.name), ["int", "boolTrue", "boolFalse", "fixture.pulse"])
        XCTAssertEqual(schema.constructors[0].fields, [])
        XCTAssertEqual(schema.constructors[0].result, .named("Int"))
        XCTAssertEqual(schema.constructors[3].result, .named("fixture.Pulse"))
    }

    func testExplicitHexadecimalIDs() throws {
        let schema = try TLParser.parse("one#FfFFffFF = One; two#00000001 value:int = Two; zero#0 = Zero;")
        XCTAssertEqual(schema.constructors.map(\.id), [UInt32.max, 1, 0])
        XCTAssertEqual(schema.constructors[1].fields, [TLField(name: "value", type: .named("int"))])
    }

    func testEverTLVectorCRCIncludesTypeParameterBraces() throws {
        let constructor = try XCTUnwrap(TLParser.parse("vector {t:Type} # [ t ] = Vector t;").constructors.first)
        XCTAssertEqual(constructor.id, 0x501a_4a14)
        XCTAssertEqual(constructor.typeParameters, [TLField(name: "t", type: .named("Type"))])
        XCTAssertEqual(constructor.fields, [
            TLField(name: nil, type: .number),
            TLField(name: nil, type: .repeated(nil, [TLField(name: nil, type: .named("t"))]))
        ])
        XCTAssertEqual(constructor.result, .generic("Vector", .named("t")))
    }

    func testFieldSpellingIsNormalizedForCRC() throws {
        let parenthesized = try TLParser.parse("sample value:(vector int) = Sample;")
        let angleBrackets = try TLParser.parse("sample   value:vector<int> = Sample;")
        let additionalSpaces = try TLParser.parse("sample\n value : ( vector int )\n= Sample;")
        XCTAssertEqual(parenthesized.constructors[0].id, 0xda6f_1790)
        XCTAssertEqual(parenthesized.constructors[0].fields, angleBrackets.constructors[0].fields)
        XCTAssertEqual(parenthesized.constructors[0].id, angleBrackets.constructors[0].id)
        XCTAssertEqual(parenthesized.constructors[0].id, additionalSpaces.constructors[0].id)
    }

    func testOriginalResultSpellingIsPreservedForCRC() throws {
        let spaced = try TLParser.parse("sample = Vector int;").constructors[0]
        let extraSpaces = try TLParser.parse("sample = Vector   int;").constructors[0]
        let angleBrackets = try TLParser.parse("sample = Vector<int>;").constructors[0]
        XCTAssertEqual(spaced.result, extraSpaces.result)
        XCTAssertEqual(spaced.result, angleBrackets.result)
        XCTAssertEqual(spaced.id, 0xd2ca_eaf6)
        XCTAssertEqual(extraSpaces.id, 0xd520_5b71)
        XCTAssertEqual(angleBrackets.id, 0xe27f_1566)
    }

    func testGenericTypeParameterNormalizationMatchesEverTL() throws {
        let constructor = try TLParser.parse("invoke {X:Type} query:!X = X;").constructors[0]
        XCTAssertEqual(constructor.id, 0x018d_e97e)
        XCTAssertEqual(constructor.fields, [TLField(name: "query", type: .typeParameter("X"))])
        XCTAssertEqual(constructor.fields[0].schemaText, "query:X")
    }

    func testFlagsAndNestedVectors() throws {
        let constructor = try TLParser.parse("""
        packet flags:# optional:flags.0?int items:flags.3?(vector bytes) active:flags.31?true = Packet;
        """).constructors[0]
        XCTAssertEqual(constructor.id, 0xe362_86d0)
        XCTAssertEqual(constructor.fields, [
            TLField(name: "flags", type: .number),
            TLField(name: "optional", type: .flagged("flags", 0, .named("int"))),
            TLField(name: "items", type: .flagged("flags", 3, .generic("vector", .named("bytes")))),
            TLField(name: "active", type: .flagged("flags", 31, .named("true")))
        ])
        let nested = try TLParser.parse("nested rows:vector<vector<ns.Item>> = Nested;").constructors[0]
        XCTAssertEqual(nested.fields[0].type, .generic("vector", .generic("vector", .named("ns.Item"))))
    }

    func testRepeatedFieldsAndAnonymousFields() throws {
        let schema = try TLParser.parse("""
        int128 4*[ int ] = Int128;
        pair 2 * [ key:int value:bytes ] = Pair;
        anonymous # int !X [ first:int 3 * [ bytes ] ] = Anonymous;
        """)
        XCTAssertEqual(schema.constructors[0].id, 0x4b92_ca35)
        XCTAssertEqual(schema.constructors[0].fields, [TLField(name: nil, type: .repeated(4, [
            TLField(name: nil, type: .named("int"))
        ]))])
        XCTAssertEqual(schema.constructors[1].id, 0xd74c_abd1)
        XCTAssertEqual(schema.constructors[1].fields[0].type, .repeated(2, [
            TLField(name: "key", type: .named("int")),
            TLField(name: "value", type: .named("bytes"))
        ]))
        XCTAssertEqual(schema.constructors[2].fields.count, 4)
        XCTAssertEqual(schema.constructors[2].fields[0].type, .number)
        XCTAssertEqual(schema.constructors[2].fields[2].type, .typeParameter("X"))
        XCTAssertEqual(schema.constructors[2].fields[3].type, .repeated(nil, [
            TLField(name: "first", type: .named("int")),
            TLField(name: nil, type: .repeated(3, [TLField(name: nil, type: .named("bytes"))]))
        ]))
    }

    func testSectionsLayerAndSourcePreservation() throws {
        let declaration = "ns.call\n  input:int = ns.Result;"
        let schema = try TLParser.parse("""
        // LAYER 42
        first = First;
        ---functions---
        \(declaration)
        ---types---
        /* Block comment */ last = Last; // Line comment
        // LAYER 43
        """)
        XCTAssertEqual(schema.layer, 43)
        XCTAssertEqual(schema.constructors.map(\.isFunction), [false, true, false])
        XCTAssertEqual(schema.constructors[1].source, declaration)
        XCTAssertEqual(schema.constructors[2].source, "last = Last;")
    }

    func testMalformedSchemasReportLineAndColumn() {
        let cases: [(String, Int, Int, String)] = [
            ("\nitem value:int = Item", 2, 22, "Expected ';'"),
            ("item value:(vector int = Item;", 1, 24, "Expected ')'"),
            ("\n/* unfinished", 2, 1, "Unterminated block comment"),
            ("item#123456789 = Item;", 1, 6, "Constructor ID"),
            ("item#zz = Item;", 1, 6, "Constructor ID"),
            ("item# 01 = Item;", 1, 6, "immediately after"),
            ("item field:flags.x?int = Item;", 1, 12, "flag reference"),
            ("item field:flags.4294967296?int = Item;", 1, 12, "flag reference"),
            ("item 4294967296*[ int ] = Item;", 1, 6, "Repeat count"),
            ("// LAYER 4294967296", 1, 10, "LAYER"),
            ("---unknown---", 1, 1, "Unexpected character"),
            ("ok = OK;\r\nwrong $ = Wrong;", 2, 7, "Unexpected character")
        ]
        for (source, line, column, message) in cases {
            XCTAssertThrowsError(try TLParser.parse(source), source) { error in
                guard let error = error as? TLParseError else {
                    return XCTFail("Expected TLParseError, received \(error)")
                }
                XCTAssertEqual(error.line, line, source)
                XCTAssertEqual(error.column, column, source)
                XCTAssertTrue(error.message.contains(message), error.description)
            }
        }
    }

    func testExcessiveTypeNestingReportsAnError() {
        let source = "nested field:" + String(repeating: "vector<", count: 256)
            + "int" + String(repeating: ">", count: 256) + " = Nested;"
        XCTAssertThrowsError(try TLParser.parse(source)) { error in
            guard let error = error as? TLParseError else {
                return XCTFail("Expected TLParseError, received \(error)")
            }
            XCTAssertTrue(error.message.contains("maximum depth"))
        }
    }

    func testSyntheticSchemaFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "syntax", withExtension: "tl", subdirectory: "Fixtures"))
        let schema = try TLParser.parse(String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(schema.layer, 17)
        XCTAssertEqual(schema.constructors.count, 14)
        XCTAssertTrue(schema.constructors.allSatisfy { $0.source.hasSuffix(";") })
        XCTAssertEqual(schema.constructors.filter(\.isFunction).map(\.name), ["fixture.fetch", "fixture.invoke"])
        XCTAssertEqual(schema.constructors.filter { $0.result == .named("fixture.Choice") }.count, 3)
        let explicit = try XCTUnwrap(schema.constructors.first { $0.name == "fixture.tagged" })
        XCTAssertEqual(explicit.id, 0x4a3b_2c1d)
        XCTAssertEqual(explicit.fields, [TLField(name: "value", type: .named("bytes"))])
    }
}
