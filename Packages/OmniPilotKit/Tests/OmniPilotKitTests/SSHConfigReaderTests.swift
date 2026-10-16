import XCTest
@testable import OmniPilotKit

final class SSHConfigReaderTests: XCTestCase {
    private func writeTempConfig(_ content: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("config")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testReadAliasesSkipsWildcardsAndComments() throws {
        let url = try writeTempConfig("""
        # a comment
        Host alpha
            HostName a.example.com
        Host *
            ServerAliveInterval 30
        Host beta gamma
            HostName b.example.com
        HostName notanalias
        """)
        let aliases = try SSHConfigReader().readAliases(configPath: url)
        XCTAssertEqual(aliases, ["alpha", "beta", "gamma"])
    }

    func testScanFindsOnlyHostsWithForwards() throws {
        let url = try writeTempConfig("""
        Host withfwd
            HostName example.com
            User bob
            LocalForward 4096 127.0.0.1:4096
            LocalForward 8080 db.internal:5432
            RemoteForward 9090 127.0.0.1:3000
        Host plain
            HostName plain.example.com
        """)
        let result = SSHConfigReader().scan(configPath: url)
        XCTAssertEqual(result.hosts.count, 1)

        let host = try XCTUnwrap(result.hosts.first)
        XCTAssertEqual(host.alias, "withfwd")
        XCTAssertEqual(host.hostname, "example.com")
        XCTAssertEqual(host.user, "bob")
        XCTAssertEqual(host.forwards.count, 3)
        XCTAssertEqual(host.localForwards.count, 2)
        XCTAssertEqual(host.remoteForwards.count, 1)
        XCTAssertEqual(host.localForwards.first?.bind.port, 4096)
        XCTAssertEqual(host.remoteForwards.first?.bind.port, 9090)
    }

    func testScanFindsDynamicForwards() throws {
        let url = try writeTempConfig("""
        Host socksonly
            HostName socks.example.com
            DynamicForward 1080
            DynamicForward 0.0.0.0:1081
        """)
        let result = SSHConfigReader().scan(configPath: url)
        XCTAssertEqual(result.hosts.count, 1)

        let host = try XCTUnwrap(result.hosts.first)
        XCTAssertEqual(host.alias, "socksonly")
        XCTAssertEqual(host.dynamicForwards.count, 2)
        XCTAssertEqual(host.dynamicForwards[0].kind, .dynamic)
        XCTAssertEqual(host.dynamicForwards[0].kind.shortLabel, "D")
        XCTAssertEqual(host.dynamicForwards[0].display, "Socks5 127.0.0.1:1080")
        XCTAssertEqual(host.dynamicForwards[1].display, "Socks5 0.0.0.0:1081")
    }

    func testTunnelCommandContainsExpectedOptions() {
        let command = SSHCommandBuilder.tunnelCommand(
            alias: "myserver",
            sshBinary: "/usr/bin/ssh",
            configPath: URL(fileURLWithPath: "/tmp/config")
        )
        XCTAssertEqual(command.executable, "/usr/bin/ssh")
        XCTAssertTrue(command.arguments.contains("-N"))
        XCTAssertTrue(command.arguments.contains("ExitOnForwardFailure=yes"))
        XCTAssertTrue(command.arguments.contains("BatchMode=yes"))
        XCTAssertEqual(command.arguments.last, "myserver")
    }
}
