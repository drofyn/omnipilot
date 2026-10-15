import Foundation

/// A concrete `Host` entry from `~/.ssh/config` that declares at least one
/// `LocalForward` or `RemoteForward`.
public struct SSHHost: Hashable, Sendable, Identifiable {
    public let alias: String
    public let hostname: String
    public let user: String?
    public let port: Int?
    public let forwards: [PortForward]

    public init(alias: String, hostname: String, user: String?, port: Int?, forwards: [PortForward]) {
        self.alias = alias
        self.hostname = hostname
        self.user = user
        self.port = port
        self.forwards = forwards
    }

    public var id: String { alias }

    public var hasForwards: Bool { !forwards.isEmpty }

    public var localForwards: [PortForward] { forwards.filter { $0.kind == .local } }
    public var remoteForwards: [PortForward] { forwards.filter { $0.kind == .remote } }

    /// `user@hostname` (with port when it is not the default 22) for display.
    public var remoteDisplay: String {
        var result = ""
        if let user, !user.isEmpty {
            result += "\(user)@"
        }
        result += hostname
        if let port, port != 22 {
            result += ":\(port)"
        }
        return result
    }

    public var summary: String {
        var parts: [String] = []
        if !localForwards.isEmpty { parts.append("\(localForwards.count) 条本地转发") }
        if !remoteForwards.isEmpty { parts.append("\(remoteForwards.count) 条远程转发") }
        return parts.joined(separator: " · ")
    }
}

/// Outcome of scanning the ssh configuration.
public struct SSHScanResult: Sendable {
    public let hosts: [SSHHost]
    public let warnings: [String]
    public let configPath: String

    public init(hosts: [SSHHost], warnings: [String], configPath: String) {
        self.hosts = hosts
        self.warnings = warnings
        self.configPath = configPath
    }
}
