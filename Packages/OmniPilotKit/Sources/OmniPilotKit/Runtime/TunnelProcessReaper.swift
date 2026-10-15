import Foundation
import Darwin

/// 清理上一次运行遗留的孤儿隧道进程。
///
/// App 被强制结束（`SIGKILL` / 崩溃 / `pkill`）时 `applicationWillTerminate`
/// 不会执行，子进程 `ssh` 会被 launchd 收养（父进程变成 pid 1）并继续占着本地
/// 端口，导致下次启动因 `ExitOnForwardFailure=yes` 而失败。启动时清掉它们即可。
///
/// 只匹配我们自己生成的命令行前缀，不会误杀用户手动启动的隧道。
public enum TunnelProcessReaper {
    @discardableResult
    public static func reap(sshBinary: String, configPath: URL) -> [Int32] {
        let signature = "\(sshBinary) -N -F \(configPath.path) -o ExitOnForwardFailure=yes"
        guard
            let result = try? ProcessRunner.run(
                executable: "/bin/ps",
                arguments: ["-axo", "pid=,ppid=,command="],
                timeout: 5
            )
        else { return [] }

        var killed: [Int32] = []
        for rawLine in result.stdout.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  Int32(parts[1]) == 1,                 // 父进程为 launchd ⇒ 孤儿
                  parts[2].hasPrefix(signature)         // 精确匹配我们的命令行
            else { continue }

            kill(pid, SIGTERM)
            killed.append(pid)
        }

        if !killed.isEmpty {
            usleep(300_000) // 给它们一点时间自行退出
            for pid in killed where kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
        }
        return killed
    }
}
