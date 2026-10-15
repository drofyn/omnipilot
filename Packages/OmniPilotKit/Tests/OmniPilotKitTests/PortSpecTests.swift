import XCTest
@testable import OmniPilotKit

final class PortSpecTests: XCTestCase {
    func testParseBarePort() {
        XCTAssertEqual(PortSpec.parse("4096"), PortSpec(address: nil, port: 4096))
    }

    func testParseAddressPort() {
        XCTAssertEqual(PortSpec.parse("127.0.0.1:4096"), PortSpec(address: "127.0.0.1", port: 4096))
    }

    func testParseBracketedIPv4() {
        XCTAssertEqual(PortSpec.parse("[127.0.0.1]:4096"), PortSpec(address: "127.0.0.1", port: 4096))
    }

    func testParseBracketedIPv6() {
        XCTAssertEqual(PortSpec.parse("[::1]:8080"), PortSpec(address: "::1", port: 8080))
    }

    func testParseInvalid() {
        XCTAssertNil(PortSpec.parse(""))
        XCTAssertNil(PortSpec.parse("abc"))
    }

    func testDescription() {
        XCTAssertEqual(PortSpec(address: nil, port: 4096).description, "4096")
        XCTAssertEqual(PortSpec(address: "127.0.0.1", port: 4096).description, "127.0.0.1:4096")
    }
}
