import Foundation

public struct SSHCommand: Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    public var display: String {
        ([executable] + arguments).map(SSHCommand.shellQuote).joined(separator: " ")
    }

    static func shellQuote(_ value: String) -> String {
        if value.isEmpty { return "''" }
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/:=@,")
        if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum SSHCommandBuilder {
    /// Builds the tunnel command for a host.
    ///
    /// `ssh -N <alias>` lets ssh apply every `LocalForward` / `RemoteForward`
    /// declared for that host, so no explicit `-L` / `-R` reconstruction is needed.
    public static func tunnelCommand(
        alias: String,
        sshBinary: String,
        configPath: URL,
        extraOptions: [String] = []
    ) -> SSHCommand {
        var arguments: [String] = ["-N", "-F", configPath.path]
        arguments += ["-o", "ExitOnForwardFailure=yes"]
        arguments += ["-o", "ServerAliveInterval=30"]
        arguments += ["-o", "ServerAliveCountMax=3"]
        arguments += ["-o", "BatchMode=yes"]
        arguments += ["-o", "ConnectTimeout=15"]
        arguments += extraOptions
        arguments.append(alias)
        return SSHCommand(executable: sshBinary, arguments: arguments)
    }
}
