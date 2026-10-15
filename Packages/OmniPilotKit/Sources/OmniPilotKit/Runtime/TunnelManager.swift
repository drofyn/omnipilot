import Foundation
import Combine

/// Owns the set of managed tunnels and keeps it in sync with `~/.ssh/config`.
@MainActor
public final class TunnelManager: ObservableObject {
    public static let shared = TunnelManager()

    @Published public private(set) var tunnels: [ManagedTunnel] = []
    @Published public private(set) var logs: [LogLine] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var warnings: [String] = []
    @Published public private(set) var configPathDisplay: String
    @Published public private(set) var lastScanDate: Date?

    public var sshBinary: String
    public var configPath: URL
    public var backoff: [TimeInterval]
    public var maxLogLines: Int = 3000

    /// Invoked when a tunnel keeps failing to stay up. Used to raise a notification.
    public var onRepeatedFailure: ((ManagedTunnel) -> Void)?

    private let fileLogger: LogFileWriter
    private var scanTask: Task<Void, Never>?

    public init(
        sshBinary: String = SSHConfigReader.defaultSSHBinary,
        configPath: URL = SSHConfigReader.defaultConfigPath,
        backoff: [TimeInterval] = [1, 2, 5, 10, 30],
        logFileURL: URL = TunnelManager.defaultLogFileURL
    ) {
        self.sshBinary = sshBinary
        self.configPath = configPath
        self.backoff = backoff
        self.fileLogger = LogFileWriter(fileURL: logFileURL)
        self.configPathDisplay = configPath.path
    }

    public nonisolated static var defaultLogFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/OmniPilot", isDirectory: true)
            .appendingPathComponent("omnipilot.log")
    }

    public var logFileURL: URL { fileLogger.fileURL }

    public var runningCount: Int {
        tunnels.filter { $0.state == .running || $0.state == .starting }.count
    }

    public var hasFailures: Bool {
        tunnels.contains { $0.state == .failed || $0.state == .retrying }
    }

    // MARK: - Actions

    /// Re-reads the ssh configuration and rebuilds the tunnel list.
    ///
    /// Hosts that were running stay running, hosts that were stopped stay stopped,
    /// and newly discovered hosts start automatically.
    public func reload() {
        guard !isScanning else { return }
        isScanning = true

        let reaped = TunnelProcessReaper.reap(sshBinary: sshBinary, configPath: configPath)
        if !reaped.isEmpty {
            appendLog(LogLine(source: "OmniPilot", text: "清理了 \(reaped.count) 个上次运行遗留的隧道进程（pid \(reaped.map(String.init).joined(separator: ", "))）"))
        }

        let previous = tunnels
        let previouslyRunning = Set(previous.filter { $0.state.isActive }.map { $0.id })
        let previousAliases = Set(previous.map { $0.id })
        for tunnel in previous { tunnel.stop() }

        let binary = sshBinary
        let path = configPath
        let backoff = self.backoff

        appendLog(LogLine(source: "OmniPilot", text: "正在扫描 \(path.path)…"))

        scanTask?.cancel()
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                SSHConfigReader(sshBinary: binary).scan(configPath: path)
            }.value

            guard let self, !Task.isCancelled else { return }
            self.apply(
                result: result,
                previouslyRunning: previouslyRunning,
                previousAliases: previousAliases,
                backoff: backoff
            )
        }
    }

    private func apply(
        result: SSHScanResult,
        previouslyRunning: Set<String>,
        previousAliases: Set<String>,
        backoff: [TimeInterval]
    ) {
        warnings = result.warnings
        configPathDisplay = result.configPath
        lastScanDate = Date()

        let newTunnels = result.hosts.map { host in
            ManagedTunnel(
                host: host,
                sshBinary: sshBinary,
                configPath: configPath,
                backoff: backoff,
                logSink: { [weak self] line in self?.appendLog(line) },
                failureSink: { [weak self] tunnel in self?.onRepeatedFailure?(tunnel) }
            )
        }
        tunnels = newTunnels
        isScanning = false

        appendLog(LogLine(source: "OmniPilot", text: "发现 \(newTunnels.count) 个带转发的 Host"))
        for warning in result.warnings {
            appendLog(LogLine(source: "OmniPilot", text: warning, isError: true))
        }

        for tunnel in newTunnels {
            let isNew = !previousAliases.contains(tunnel.id)
            if isNew || previouslyRunning.contains(tunnel.id) {
                tunnel.start()
            }
        }
    }

    public func startAll() {
        for tunnel in tunnels { tunnel.start() }
    }

    public func stopAll() {
        for tunnel in tunnels { tunnel.stop() }
    }

    public func restartAll() {
        for tunnel in tunnels { tunnel.restart() }
    }

    /// Synchronously kills every child process. Called on app termination.
    public func terminateAllImmediately() {
        for tunnel in tunnels { tunnel.terminateImmediately() }
    }

    // MARK: - Logs

    public func appendLog(_ line: LogLine) {
        logs.append(line)
        if logs.count > maxLogLines {
            logs.removeFirst(logs.count - maxLogLines)
        }
        let prefix = line.isError ? "ERROR" : "INFO "
        fileLogger.append("\(prefix) [\(line.source)] \(line.text)", at: line.date)
    }

    public func clearLogs() {
        logs.removeAll()
        fileLogger.clear()
    }
}
