import Foundation
import Darwin

/// Reads `~/.ssh/config` and resolves every concrete `Host` that declares a
/// `LocalForward`, `RemoteForward`, or `DynamicForward`.
///
/// The ssh configuration is treated as **read-only**. Host aliases are collected
/// by a light scan of `Host` / `Include` lines, then each alias is resolved with
/// `ssh -G <alias>`, which yields the effective (fully expanded) configuration
/// including forwards inherited from wildcards or `Match` blocks.
public struct SSHConfigReader: Sendable {
    public static let defaultSSHBinary = "/usr/bin/ssh"

    public static var defaultConfigPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
    }

    public let sshBinary: String

    public init(sshBinary: String = SSHConfigReader.defaultSSHBinary) {
        self.sshBinary = sshBinary
    }

    public func scan(configPath: URL = SSHConfigReader.defaultConfigPath) -> SSHScanResult {
        let aliases: [String]
        do {
            aliases = try readAliases(configPath: configPath)
        } catch {
            return SSHScanResult(
                hosts: [],
                warnings: ["无法读取 ssh 配置 \(configPath.path)：\(error.localizedDescription)"],
                configPath: configPath.path
            )
        }

        var hosts: [SSHHost] = []
        var warnings: [String] = []
        for alias in aliases {
            guard let host = resolve(alias: alias, configPath: configPath) else {
                warnings.append("无法解析 Host 「\(alias)」")
                continue
            }
            if host.hasForwards {
                hosts.append(host)
            }
        }
        return SSHScanResult(hosts: hosts, warnings: warnings, configPath: configPath.path)
    }

    /// Collect the concrete `Host` aliases declared in the given config file.
    public func readAliases(configPath: URL, depth: Int = 0) throws -> [String] {
        guard depth <= 5 else { return [] }
        let text = try String(contentsOf: configPath, encoding: .utf8)
        let baseDirectory = configPath.deletingLastPathComponent()

        var aliases: [String] = []
        var seen = Set<String>()

        for rawLine in text.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let keyword = tokens.first?.lowercased() else { continue }

            if keyword == "host" {
                for alias in tokens.dropFirst() {
                    guard !alias.contains("*"), !alias.contains("?"), !alias.contains("!") else { continue }
                    if seen.insert(alias).inserted {
                        aliases.append(alias)
                    }
                }
            } else if keyword == "include" {
                for pattern in tokens.dropFirst() {
                    for url in expandIncludes(pattern: pattern, baseDirectory: baseDirectory) {
                        guard let nested = try? readAliases(configPath: url, depth: depth + 1) else { continue }
                        for alias in nested where seen.insert(alias).inserted {
                            aliases.append(alias)
                        }
                    }
                }
            }
        }
        return aliases
    }

    /// Resolve one alias through `ssh -G` and extract its identity and forwards.
    public func resolve(alias: String, configPath: URL) -> SSHHost? {
        let result: ProcessResult
        do {
            result = try ProcessRunner.run(
                executable: sshBinary,
                arguments: ["-G", "-F", configPath.path, alias],
                timeout: 10
            )
        } catch {
            return nil
        }
        guard result.status == 0 || !result.stdout.isEmpty else { return nil }

        var hostname: String?
        var user: String?
        var port: Int?
        var forwards: [PortForward] = []

        for rawLine in result.stdout.components(separatedBy: .newlines) {
            let parts = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let key = parts.first?.lowercased() else { continue }
            switch key {
            case "hostname":
                if parts.count > 1 { hostname = parts[1] }
            case "user":
                if parts.count > 1 { user = parts[1] }
            case "port":
                if parts.count > 1 { port = Int(parts[1]) }
            case "localforward", "remoteforward":
                let kind: ForwardKind = (key == "localforward") ? .local : .remote
                let specs = Array(parts.dropFirst())
                if specs.count >= 2,
                   let bind = PortSpec.parse(specs[0]),
                   let target = PortSpec.parse(specs[1]) {
                    forwards.append(PortForward(kind: kind, bind: bind, target: target))
                }
            case "dynamicforward":
                let specs = Array(parts.dropFirst())
                if let first = specs.first,
                   let bind = PortSpec.parse(first) {
                    forwards.append(PortForward(kind: .dynamic, bind: bind))
                }
            default:
                break
            }
        }

        guard let resolvedHostname = hostname, !resolvedHostname.isEmpty else { return nil }
        return SSHHost(alias: alias, hostname: resolvedHostname, user: user, port: port, forwards: forwards)
    }

    // MARK: - Helpers

    private func stripComment(_ line: String) -> String {
        if let index = line.firstIndex(of: "#") {
            return String(line[..<index])
        }
        return line
    }

    private func expandIncludes(pattern: String, baseDirectory: URL) -> [URL] {
        var path = (pattern as NSString).expandingTildeInPath
        if !path.hasPrefix("/") {
            path = baseDirectory.appendingPathComponent(path).path
        }
        var globResult = glob_t()
        defer { globfree(&globResult) }
        guard glob(path, 0, nil, &globResult) == 0 else { return [] }
        var urls: [URL] = []
        for index in 0..<Int(globResult.gl_pathc) {
            guard let cString = globResult.gl_pathv[index] else { continue }
            urls.append(URL(fileURLWithPath: String(cString: cString)))
        }
        return urls
    }
}
