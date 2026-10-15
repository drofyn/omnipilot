import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public init(status: Int32, stdout: String, stderr: String) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ProcessRunnerError: Error, LocalizedError {
    case launchFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message): return message
        case .timedOut: return "命令执行超时"
        }
    }
}

/// 同步执行一个短命令并收集其输出。
///
/// stdout/stderr 会**并发读取**：管道缓冲区只有 64KB，若先等进程退出再读，
/// 输出超过缓冲区的命令（例如 `ps -axo …`）会因写满而阻塞、直至超时。
public enum ProcessRunner {
    @discardableResult
    public static func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 10,
        environment: [String: String]? = nil
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let environment {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in environment { merged[key] = value }
            process.environment = merged
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let lock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()
        let readGroup = DispatchGroup()
        let ioQueue = DispatchQueue(
            label: "com.drofyn.omnipilot.process.io",
            attributes: .concurrent
        )

        readGroup.enter()
        ioQueue.async {
            let data = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
            lock.lock(); stdoutData = data; lock.unlock()
            readGroup.leave()
        }
        readGroup.enter()
        ioQueue.async {
            let data = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
            lock.lock(); stderrData = data; lock.unlock()
            readGroup.leave()
        }

        var timedOut = false
        let deadline = Date().addingTimeInterval(max(timeout, 0.1))
        while process.isRunning && Date() < deadline {
            usleep(15_000)
        }
        if process.isRunning {
            timedOut = true
            process.terminate()
            let killDeadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < killDeadline {
                usleep(15_000)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        readGroup.wait()
        process.waitUntilExit()

        if timedOut {
            throw ProcessRunnerError.timedOut
        }

        lock.lock()
        let out = stdoutData
        let err = stderrData
        lock.unlock()

        return ProcessResult(
            status: process.terminationStatus,
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self)
        )
    }
}
