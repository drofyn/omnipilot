import Foundation
import Combine

public typealias LogSink = @MainActor (LogLine) -> Void
public typealias TunnelFailureSink = @MainActor (ManagedTunnel) -> Void

/// Supervises a single `ssh -N <alias>` process: starts it, streams its output,
/// and restarts it with backoff whenever it exits unexpectedly.
@MainActor
public final class ManagedTunnel: ObservableObject, Identifiable {
    nonisolated public let host: SSHHost
    nonisolated public var id: String { host.alias }

    @Published public private(set) var state: TunnelState = .stopped
    @Published public private(set) var lastError: String?
    @Published public private(set) var pid: Int32?
    @Published public private(set) var restartCount: Int = 0

    private let sshBinary: String
    private let configPath: URL
    private let extraOptions: [String]
    private let backoff: [TimeInterval]
    private let logSink: LogSink
    private let failureSink: TunnelFailureSink

    private var process: Process?
    private var outputPipe: Pipe?
    private var intentionallyStopped = false
    private var consecutiveFailures = 0
    private var notifiedThisStreak = false
    private var retryTask: Task<Void, Never>?
    private var stabilityTask: Task<Void, Never>?
    private var outputBuffer = ""
    private var recentLines: [String] = []

    public init(
        host: SSHHost,
        sshBinary: String,
        configPath: URL,
        extraOptions: [String] = [],
        backoff: [TimeInterval] = [1, 2, 5, 10, 30],
        logSink: @escaping LogSink,
        failureSink: @escaping TunnelFailureSink
    ) {
        self.host = host
        self.sshBinary = sshBinary
        self.configPath = configPath
        self.extraOptions = extraOptions
        self.backoff = backoff.isEmpty ? [1, 2, 5, 10, 30] : backoff
        self.logSink = logSink
        self.failureSink = failureSink
    }

    public var command: SSHCommand {
        SSHCommandBuilder.tunnelCommand(
            alias: host.alias,
            sshBinary: sshBinary,
            configPath: configPath,
            extraOptions: extraOptions
        )
    }

    public var isRunning: Bool { process != nil }

    // MARK: - Lifecycle

    public func start() {
        intentionallyStopped = false
        if process != nil { return }
        retryTask?.cancel()
        retryTask = nil
        launch()
    }

    public func stop() {
        intentionallyStopped = true
        retryTask?.cancel()
        retryTask = nil
        stabilityTask?.cancel()
        stabilityTask = nil
        consecutiveFailures = 0
        notifiedThisStreak = false

        guard let running = process else {
            state = .stopped
            lastError = nil
            return
        }
        state = .stopping
        running.terminate()

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, let current = self.process, current.isRunning else { return }
            kill(current.processIdentifier, SIGKILL)
        }
    }

    public func restart() {
        stop()
        Task { @MainActor [weak self] in
            guard let self else { return }
            var waited: Double = 0
            while self.process != nil && waited < 4 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waited += 0.1
            }
            if let current = self.process, current.isRunning {
                kill(current.processIdentifier, SIGKILL)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            self.start()
        }
    }

    /// Kills the child process synchronously. Used while the app is terminating,
    /// where async cleanup would not have time to run and the ssh child would
    /// otherwise be left orphaned.
    public func terminateImmediately() {
        intentionallyStopped = true
        retryTask?.cancel()
        retryTask = nil
        stabilityTask?.cancel()
        stabilityTask = nil
        if let process, process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    // MARK: - Process

    private func launch() {
        guard process == nil else { return }
        let command = command

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        outputPipe = pipe
        outputBuffer = ""
        recentLines = []

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.ingest(text) }
        }

        process.terminationHandler = { [weak self] finished in
            Task { @MainActor [weak self] in self?.handleExit(finished) }
        }

        do {
            try process.run()
        } catch {
            outputPipe = nil
            process.terminationHandler = nil
            lastError = error.localizedDescription
            state = .failed
            log("启动失败：\(error.localizedDescription)", isError: true)
            scheduleRetry()
            return
        }

        self.process = process
        pid = process.processIdentifier
        state = .starting
        lastError = nil
        log("启动 「\(host.alias)」（pid \(process.processIdentifier)）")

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.process != nil, self.state == .starting {
                self.state = .running
                self.scheduleStabilityReset()
            }
        }
    }

    private func handleExit(_ finished: Process) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        process = nil
        pid = nil
        stabilityTask?.cancel()
        stabilityTask = nil

        if intentionallyStopped {
            state = .stopped
            lastError = nil
            log("已停止 「\(host.alias)」")
            return
        }

        consecutiveFailures += 1
        restartCount += 1
        let detail = exitDetail(status: finished.terminationStatus)
        lastError = detail
        log("「\(host.alias)」 意外退出（\(detail)）", isError: true)

        if consecutiveFailures >= 3 && !notifiedThisStreak {
            notifiedThisStreak = true
            failureSink(self)
        }

        scheduleRetry()
    }

    private func exitDetail(status: Int32) -> String {
        if let line = recentLines.last(where: { isLikelyError($0) }) {
            return line
        }
        if let line = recentLines.last {
            return line
        }
        return "退出码 \(status)"
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let delay = backoff[min(max(consecutiveFailures - 1, 0), backoff.count - 1)]
        state = .retrying
        log("「\(host.alias)」 \(Int(delay)) 秒后重连（第 \(consecutiveFailures) 次）")
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled, !self.intentionallyStopped else { return }
            self.retryTask = nil
            self.launch()
        }
    }

    private func scheduleStabilityReset() {
        stabilityTask?.cancel()
        stabilityTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.state == .running {
                self.consecutiveFailures = 0
                self.notifiedThisStreak = false
            }
        }
    }

    // MARK: - Output

    private func ingest(_ text: String) {
        outputBuffer += text
        while let range = outputBuffer.range(of: "\n") {
            let line = String(outputBuffer[outputBuffer.startIndex..<range.lowerBound])
            outputBuffer.removeSubrange(outputBuffer.startIndex..<range.upperBound)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            recentLines.append(trimmed)
            if recentLines.count > 8 { recentLines.removeFirst() }
            log(trimmed, isError: isLikelyError(trimmed))
        }
    }

    private func isLikelyError(_ line: String) -> Bool {
        let lower = line.lowercased()
        for needle in ["error", "fail", "denied", "refused", "unable", "cannot", "warning", "permission"] {
            if lower.contains(needle) { return true }
        }
        return false
    }

    private func log(_ text: String, isError: Bool = false) {
        logSink(LogLine(source: host.alias, text: text, isError: isError))
    }
}
