import Foundation
import XCTest
@testable import EverTLCodegen

final class TLConstructorIDTests: XCTestCase {
    func testSyntheticConstructorIDsMatchIndependentCRCValues() throws {
        // Expected CRC-32 values were computed with Python's zlib from
        // manually normalized signatures, independently of the Swift parser.
        let fixtures = try XCTUnwrap(Bundle.module.resourceURL).appendingPathComponent("Fixtures")
        let reference = try String(
            contentsOf: fixtures.appendingPathComponent("constructor-ids.tsv"), encoding: .utf8
        )
        let schema = try TLParser.parse(String(
            contentsOf: fixtures.appendingPathComponent("syntax.tl"), encoding: .utf8
        ))
        let actual = schema.constructors.map {
            "\($0.name)\t\(String(format: "%08x", $0.id))\n"
        }.joined()
        XCTAssertEqual(actual, reference)
    }
}
